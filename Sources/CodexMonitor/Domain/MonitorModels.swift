import Foundation

struct WeeklyQuota: Equatable, Sendable {
    let remainingPercent: Double?
    let resetsAt: Date?
}

struct UsageDay: Identifiable, Equatable, Sendable {
    var id: Date { date }

    let date: Date
    let tokens: Int
    let sessions: Int
}

enum ProjectRunState: Int, Codable, Sendable {
    case failed = 0
    case running = 1
    case completed = 2
}

struct ProjectActivity: Identifiable, Equatable, Sendable {
    var id: String { name }

    let name: String
    let state: ProjectRunState
    let updatedAt: Date
}

extension Array where Element == ProjectActivity {
    func visibleForMenu(at now: Date = .now) -> [ProjectActivity] {
        filter {
            ProjectVisibilityPolicy.isVisible(
                updatedAt: $0.updatedAt,
                now: now
            )
        }
    }

    var sortedForMenu: [ProjectActivity] {
        sorted {
            if $0.state.rawValue != $1.state.rawValue {
                return $0.state.rawValue < $1.state.rawValue
            }
            return $0.updatedAt > $1.updatedAt
        }
    }
}

enum ProjectVisibilityPolicy {
    static let inactivityTimeout: TimeInterval = 60

    static func isVisible(updatedAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(updatedAt) < inactivityTimeout
    }
}

struct MonitorSnapshot: Equatable, Sendable {
    let weeklyQuota: WeeklyQuota
    let dailyActivity: [UsageDay]
    let lifetimeTokens: Int
    let peakTokens: Int
    let longestTaskDuration: TimeInterval
    let currentStreakDays: Int
    let longestStreakDays: Int
    let projects: [ProjectActivity]
    let lastUpdatedAt: Date?

    static let empty = MonitorSnapshot(
        weeklyQuota: WeeklyQuota(remainingPercent: nil, resetsAt: nil),
        dailyActivity: [],
        lifetimeTokens: 0,
        peakTokens: 0,
        longestTaskDuration: 0,
        currentStreakDays: 0,
        longestStreakDays: 0,
        projects: [],
        lastUpdatedAt: nil
    )
}
