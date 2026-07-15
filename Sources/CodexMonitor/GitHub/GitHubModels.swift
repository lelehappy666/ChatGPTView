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
    static let privacyNote = "仅请求读取公开仓库与活动数据"
}

enum GitHubAuthorizationAction: Equatable {
    case openTokenPage
    case bind(token: String)

    static func next(clipboard: String?) -> GitHubAuthorizationAction {
        let token = clipboard?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if token.hasPrefix("github_pat_") || token.hasPrefix("ghp_") {
            return .bind(token: token)
        }
        return .openTokenPage
    }
}

enum GitHubContributionScale {
    static let maximumExpectedCount = 30

    static func level(count: Int) -> Int {
        switch Swift.max(0, Swift.min(count, maximumExpectedCount)) {
        case 0: return 0
        case 1...3: return 1
        case 4...9: return 2
        case 10...19: return 3
        default: return 4
        }
    }
}

enum GitHubContributionTooltip {
    static func text(
        for day: GitHubContributionDay,
        calendar: Calendar = .current
    ) -> String {
        let components = calendar.dateComponents([.month, .day], from: day.date)
        let dateText = "\(components.month ?? 0)月\(components.day ?? 0)日"
        return "\(dateText) · \(day.contributionCount) 次贡献"
    }
}

enum GitHubRepositoryLinkPolicy {
    static func canOpen(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" &&
            url.host?.lowercased() == "github.com"
    }
}

struct GitHubContributionRenderCell: Equatable {
    let day: GitHubContributionDay
    let rect: CGRect
    let level: Int
}

enum GitHubContributionRenderPlan {
    static func cells(
        days: [GitHubContributionDay],
        width: CGFloat,
        spacing: CGFloat
    ) -> [GitHubContributionRenderCell] {
        guard !days.isEmpty else { return [] }
        let columns = Int(ceil(Double(days.count) / 7.0))
        let availableWidth = width - CGFloat(Swift.max(0, columns - 1)) * spacing
        let cellSize = Swift.max(0, availableWidth / CGFloat(columns))

        return days.enumerated().map { index, day in
            let column = index / 7
            let row = index % 7
            return GitHubContributionRenderCell(
                day: day,
                rect: CGRect(
                    x: CGFloat(column) * (cellSize + spacing),
                    y: CGFloat(row) * (cellSize + spacing),
                    width: cellSize,
                    height: cellSize
                ),
                level: GitHubContributionScale.level(count: day.contributionCount)
            )
        }
    }

    static func day(
        at point: CGPoint,
        cells: [GitHubContributionRenderCell]
    ) -> GitHubContributionDay? {
        cells.first(where: { $0.rect.contains(point) })?.day
    }
}
