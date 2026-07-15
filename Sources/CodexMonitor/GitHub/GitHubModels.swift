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
