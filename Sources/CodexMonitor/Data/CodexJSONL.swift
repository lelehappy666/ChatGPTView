import Foundation

struct CodexEnvelope: Decodable {
    let type: String
    let timestamp: String?
    let payload: Payload

    struct Payload: Decodable {
        let type: String?
        let timestamp: String?
        let cwd: String?
        let id: String?
        let sessionID: String?
        let agentNickname: String?
        let parentThreadID: String?
        let source: CodexSessionSource?
        let turnID: String?
        let message: String?
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
            case message
            case sessionID = "session_id"
            case agentNickname = "agent_nickname"
            case parentThreadID = "parent_thread_id"
            case source
            case turnID = "turn_id"
            case startedAt = "started_at"
            case completedAt = "completed_at"
            case durationMS = "duration_ms"
            case rateLimits = "rate_limits"
        }
    }
}

struct CodexSessionSource: Decodable {
    let isInternal: Bool

    init(from decoder: Decoder) throws {
        isInternal = try CodexSourceValue(from: decoder).containsInternalMarker
    }
}

private indirect enum CodexSourceValue: Decodable {
    case string(String)
    case object([String: CodexSourceValue])
    case array([CodexSourceValue])
    case scalar

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .scalar
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: CodexSourceValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([CodexSourceValue].self) {
            self = .array(value)
        } else if (try? container.decode(Bool.self)) != nil ||
                    (try? container.decode(Double.self)) != nil {
            self = .scalar
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "无法解析 Codex 会话来源"
            )
        }
    }

    var containsInternalMarker: Bool {
        switch self {
        case .string, .scalar:
            return false
        case let .array(values):
            return values.contains(where: \.containsInternalMarker)
        case let .object(values):
            for (key, value) in values {
                if key.caseInsensitiveCompare("subagent") == .orderedSame {
                    return true
                }
                if key.caseInsensitiveCompare("other") == .orderedSame,
                   case let .string(name) = value,
                   name.caseInsensitiveCompare("guardian") == .orderedSame {
                    return true
                }
                if value.containsInternalMarker {
                    return true
                }
            }
            return false
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
    let sessionTitle: String?
    let turnID: String?
    let isTopLevel: Bool
    let totalTokens: Int
    let longestTaskDuration: TimeInterval
    let state: ProjectRunState
    let updatedAt: Date
    let weeklyUsedPercent: Double?
    let weeklyLimitID: String?
    let weeklyResetsAt: Date?
    let weeklyQuotaUpdatedAt: Date?

    init(
        date: Date,
        projectName: String?,
        sessionID: String = "",
        agentNickname: String? = nil,
        sessionTitle: String? = nil,
        turnID: String? = nil,
        isTopLevel: Bool = true,
        totalTokens: Int,
        longestTaskDuration: TimeInterval,
        state: ProjectRunState,
        updatedAt: Date,
        weeklyUsedPercent: Double?,
        weeklyLimitID: String? = nil,
        weeklyResetsAt: Date?,
        weeklyQuotaUpdatedAt: Date? = nil
    ) {
        self.date = date
        self.projectName = projectName
        self.sessionID = sessionID
        self.agentNickname = agentNickname
        self.sessionTitle = sessionTitle
        self.turnID = turnID
        self.isTopLevel = isTopLevel
        self.totalTokens = totalTokens
        self.longestTaskDuration = longestTaskDuration
        self.state = state
        self.updatedAt = updatedAt
        self.weeklyUsedPercent = weeklyUsedPercent
        self.weeklyLimitID = weeklyLimitID
        self.weeklyResetsAt = weeklyResetsAt
        self.weeklyQuotaUpdatedAt = weeklyQuotaUpdatedAt
    }
}
