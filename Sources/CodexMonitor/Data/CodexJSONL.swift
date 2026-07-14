import Foundation

struct CodexEnvelope: Decodable {
    let type: String
    let payload: Payload

    struct Payload: Decodable {
        let type: String?
        let timestamp: String?
        let cwd: String?
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
            case reason
            case info
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
    let primary: RateWindow?
    let secondary: RateWindow?

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
    let projectName: String
    let totalTokens: Int
    let longestTaskDuration: TimeInterval
    let state: ProjectRunState
    let updatedAt: Date
    let weeklyUsedPercent: Double?
    let weeklyResetsAt: Date?
}
