import Foundation

struct CodexEnvelope: Decodable {
    let type: String
    let payload: Payload

    struct Payload: Decodable {
        let type: String?
        let timestamp: String?
        let cwd: String?
        let id: String?
        let sessionID: String?
        let agentNickname: String?
        let startedAt: Double?
        let completedAt: Double?
        let durationMS: Double?
        let reason: String?
        let info: TokenInfo?
        let rateLimits: RateLimits?

        enum CodingKeys: String, CodingKey {
            case type
            case timestamp
            case cwd
            case id
            case reason
            case info
            case sessionID = "session_id"
            case agentNickname = "agent_nickname"
            case startedAt = "started_at"
            case completedAt = "completed_at"
            case durationMS = "duration_ms"
            case rateLimits = "rate_limits"
        }
    }
}

struct TokenInfo: Decodable {
    let totalTokenUsage: TokenUsage?

    enum CodingKeys: String, CodingKey {
        case totalTokenUsage = "total_token_usage"
    }
}

struct TokenUsage: Decodable {
    let totalTokens: Int?

    enum CodingKeys: String, CodingKey {
        case totalTokens = "total_tokens"
    }
}

struct RateLimits: Decodable {
    let limitID: String?
    let primary: RateWindow?
    let secondary: RateWindow?

    enum CodingKeys: String, CodingKey {
        case limitID = "limit_id"
        case primary
        case secondary
    }

    var weeklyWindow: RateWindow? {
        [primary, secondary]
            .compactMap { $0 }
            .first { $0.windowMinutes == 10_080 }
    }
}

struct RateWindow: Decodable {
    let usedPercent: Double?
    let windowMinutes: Int?
    let resetsAt: Double?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case windowMinutes = "window_minutes"
        case resetsAt = "resets_at"
    }
}

struct SessionSummary: Equatable, Sendable {
    let date: Date
    let projectName: String?
    let sessionID: String
    let agentNickname: String?
    let totalTokens: Int
    let longestTaskDuration: TimeInterval
    let state: ProjectRunState
    let updatedAt: Date
    let weeklyUsedPercent: Double?
    let weeklyLimitID: String?
    let weeklyResetsAt: Date?

    init(
        date: Date,
        projectName: String?,
        sessionID: String = "",
        agentNickname: String? = nil,
        totalTokens: Int,
        longestTaskDuration: TimeInterval,
        state: ProjectRunState,
        updatedAt: Date,
        weeklyUsedPercent: Double?,
        weeklyLimitID: String? = nil,
        weeklyResetsAt: Date?
    ) {
        self.date = date
        self.projectName = projectName
        self.sessionID = sessionID
        self.agentNickname = agentNickname
        self.totalTokens = totalTokens
        self.longestTaskDuration = longestTaskDuration
        self.state = state
        self.updatedAt = updatedAt
        self.weeklyUsedPercent = weeklyUsedPercent
        self.weeklyLimitID = weeklyLimitID
        self.weeklyResetsAt = weeklyResetsAt
    }
}
