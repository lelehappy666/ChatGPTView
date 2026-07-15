import Foundation

protocol GitHubActivityLoading: Sendable {
    func fetchActivity(token: String) async throws -> GitHubActivitySnapshot
}

enum GitHubAPIError: Error, Equatable, LocalizedError {
    case invalidToken
    case rateLimited
    case server(statusCode: Int)
    case malformedResponse
    case message(String)

    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "GitHub 授权已失效，请重新绑定"
        case .rateLimited:
            return "GitHub 请求次数已达上限，请稍后重试"
        case .server:
            return "GitHub 服务暂时不可用"
        case .malformedResponse:
            return "GitHub 返回了无法识别的数据"
        case .message(let message):
            return message
        }
    }
}

final class GitHubGraphQLClient: GitHubActivityLoading, @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchActivity(token: String) async throws -> GitHubActivitySnapshot {
        let request = try Self.makeRequest(token: token)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.malformedResponse
        }
        return try Self.decode(
            data: data,
            statusCode: httpResponse.statusCode,
            fetchedAt: .now
        )
    }

    static func makeRequest(token: String) throws -> URLRequest {
        guard let url = URL(string: "https://api.github.com/graphql") else {
            throw GitHubAPIError.malformedResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("CodexMonitor/0.1", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(GraphQLRequest(query: query))
        return request
    }

    static func decode(
        data: Data,
        statusCode: Int,
        fetchedAt: Date
    ) throws -> GitHubActivitySnapshot {
        switch statusCode {
        case 401:
            throw GitHubAPIError.invalidToken
        case 429:
            throw GitHubAPIError.rateLimited
        case 200..<300:
            break
        default:
            throw GitHubAPIError.server(statusCode: statusCode)
        }

        let response: GraphQLResponse
        do {
            response = try JSONDecoder().decode(GraphQLResponse.self, from: data)
        } catch {
            throw GitHubAPIError.malformedResponse
        }

        if let message = response.errors?.first?.message {
            if message.localizedCaseInsensitiveContains("rate limit") {
                throw GitHubAPIError.rateLimited
            }
            throw GitHubAPIError.message(message)
        }
        guard let viewer = response.data?.viewer else {
            throw GitHubAPIError.malformedResponse
        }

        let dateOnly = DateFormatter()
        dateOnly.calendar = Calendar(identifier: .gregorian)
        dateOnly.locale = Locale(identifier: "en_US_POSIX")
        dateOnly.timeZone = TimeZone(secondsFromGMT: 0)
        dateOnly.dateFormat = "yyyy-MM-dd"
        let iso8601 = ISO8601DateFormatter()

        let calendar = viewer.contributionsCollection.contributionCalendar
        let contributionDays: [GitHubContributionDay] = calendar.weeks
            .flatMap(\.contributionDays)
            .compactMap { day -> GitHubContributionDay? in
            guard let date = dateOnly.date(from: day.date) else { return nil }
            return GitHubContributionDay(
                date: date,
                contributionCount: day.contributionCount
            )
        }
        let repositories: [GitHubRepository] = viewer.repositories.nodes.compactMap { repository in
            guard let url = URL(string: repository.url),
                  let pushedAt = iso8601.date(from: repository.pushedAt) else {
                return nil
            }
            return GitHubRepository(
                name: repository.name,
                url: url,
                pushedAt: pushedAt
            )
        }.recentlyPushed(limit: 6)

        return GitHubActivitySnapshot(
            username: viewer.login,
            totalContributions: calendar.totalContributions,
            contributionDays: contributionDays,
            repositories: repositories,
            fetchedAt: fetchedAt
        )
    }

    private static let query = #"""
    query CodexMonitorActivity {
      viewer {
        login
        contributionsCollection {
          contributionCalendar {
            totalContributions
            weeks {
              contributionDays {
                date
                contributionCount
              }
            }
          }
        }
        repositories(
          first: 6
          ownerAffiliations: OWNER
          orderBy: {field: PUSHED_AT, direction: DESC}
          privacy: PUBLIC
        ) {
          nodes {
            name
            url
            pushedAt
          }
        }
      }
    }
    """#
}

private struct GraphQLRequest: Encodable {
    let query: String
}

private struct GraphQLResponse: Decodable {
    let data: ResponseData?
    let errors: [GraphQLError]?
}

private struct GraphQLError: Decodable {
    let message: String
}

private struct ResponseData: Decodable {
    let viewer: Viewer
}

private struct Viewer: Decodable {
    let login: String
    let contributionsCollection: ContributionsCollection
    let repositories: RepositoryConnection
}

private struct ContributionsCollection: Decodable {
    let contributionCalendar: ContributionCalendar
}

private struct ContributionCalendar: Decodable {
    let totalContributions: Int
    let weeks: [ContributionWeek]
}

private struct ContributionWeek: Decodable {
    let contributionDays: [ContributionDay]
}

private struct ContributionDay: Decodable {
    let date: String
    let contributionCount: Int
}

private struct RepositoryConnection: Decodable {
    let nodes: [RepositoryNode]
}

private struct RepositoryNode: Decodable {
    let name: String
    let url: String
    let pushedAt: String
}
