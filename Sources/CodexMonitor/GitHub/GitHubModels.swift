import Foundation

struct GitHubContributionDay: Identifiable, Codable, Equatable, Sendable {
    var id: Date { date }

    let date: Date
    let contributionCount: Int
}

struct GitHubRepository: Identifiable, Codable, Equatable, Sendable {
    var id: URL { url }

    let name: String
    let url: URL
    let pushedAt: Date
}

struct GitHubActivitySnapshot: Codable, Equatable, Sendable {
    let username: String
    let totalContributions: Int
    let contributionDays: [GitHubContributionDay]
    let repositories: [GitHubRepository]
    let fetchedAt: Date
}

extension Array where Element == GitHubRepository {
    func recentlyPushed(limit: Int = 6) -> [GitHubRepository] {
        Array(sorted { $0.pushedAt > $1.pushedAt }.prefix(Swift.max(0, limit)))
    }
}

enum GitHubAuthorizationContent {
    static let title = "连接 GitHub"
    static let message = "授权后查看贡献记录和最近更新的仓库"
    static let primaryAction = "授权 GitHub"
    static let privacyNote = "令牌仅存储在本机钥匙串"
}

enum GitHubContributionScale {
    static func level(count: Int, maximum: Int) -> Int {
        guard count > 0 else { return 0 }
        let ratio = Double(count) / Double(Swift.max(1, maximum))
        switch ratio {
        case ...0.25: return 1
        case ...0.50: return 2
        case ...0.75: return 3
        default: return 4
        }
    }
}

enum GitHubRepositoryLinkPolicy {
    static func canOpen(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" &&
            url.host?.lowercased() == "github.com"
    }
}
