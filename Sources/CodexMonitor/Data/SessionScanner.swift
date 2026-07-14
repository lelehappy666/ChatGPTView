import Foundation

enum SessionScanner {
    static func scan(root: URL) async throws -> [SessionSummary] {
        try await Task.detached(priority: .utility) {
            try scanSynchronously(root: root)
        }.value
    }

    private static func scanSynchronously(root: URL) throws -> [SessionSummary] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var summaries: [SessionSummary] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            if let summary = try parseFile(url) {
                summaries.append(summary)
            }
        }
        return summaries
    }

    static func parseFile(_ url: URL) throws -> SessionSummary? {
        let text = try String(contentsOf: url, encoding: .utf8)
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()

        var timestamp: Date?
        var cwd: String?
        var tokens = 0
        var longestTaskDuration: TimeInterval = 0
        var state: ProjectRunState = .completed
        var updatedAt = Date.distantPast
        var weeklyUsedPercent: Double?
        var weeklyResetsAt: Date?

        for line in text.split(separator: "\n") {
            guard isRelevant(line),
                  let envelope = try? decoder.decode(CodexEnvelope.self, from: Data(line.utf8)) else {
                continue
            }

            let payload = envelope.payload
            switch payload.type {
            case "session_meta":
                cwd = payload.cwd
                timestamp = payload.timestamp.flatMap { formatter.date(from: $0) }
            case "task_started":
                state = .running
                updatedAt = payload.startedAt.map(Date.init(timeIntervalSince1970:)) ?? updatedAt
            case "task_complete":
                state = .completed
                longestTaskDuration = max(longestTaskDuration, (payload.durationMS ?? 0) / 1_000)
                updatedAt = payload.completedAt.map(Date.init(timeIntervalSince1970:)) ?? updatedAt
            case "turn_aborted":
                state = .failed
                longestTaskDuration = max(longestTaskDuration, (payload.durationMS ?? 0) / 1_000)
                updatedAt = payload.completedAt.map(Date.init(timeIntervalSince1970:)) ?? updatedAt
            case "token_count":
                tokens = payload.info?.totalTokenUsage?.totalTokens ?? tokens
                if payload.rateLimits?.primary?.windowMinutes == 10_080 {
                    weeklyUsedPercent = payload.rateLimits?.primary?.usedPercent
                    weeklyResetsAt = payload.rateLimits?.primary?.resetsAt
                        .map(Date.init(timeIntervalSince1970:))
                }
            default:
                break
            }
        }

        guard let timestamp, let cwd else {
            return nil
        }

        return SessionSummary(
            date: timestamp,
            projectName: URL(fileURLWithPath: cwd).lastPathComponent,
            totalTokens: tokens,
            longestTaskDuration: longestTaskDuration,
            state: state,
            updatedAt: updatedAt == .distantPast ? timestamp : updatedAt,
            weeklyUsedPercent: weeklyUsedPercent,
            weeklyResetsAt: weeklyResetsAt
        )
    }

    private static func isRelevant(_ line: Substring) -> Bool {
        line.contains("session_meta") ||
            line.contains("task_started") ||
            line.contains("task_complete") ||
            line.contains("turn_aborted") ||
            line.contains("token_count")
    }
}
