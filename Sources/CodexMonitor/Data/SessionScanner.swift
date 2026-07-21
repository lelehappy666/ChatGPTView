import Foundation

enum SessionScanner {
    private struct LifecycleEvent {
        let state: ProjectRunState
        let updatedAt: Date?
        let duration: TimeInterval
        let turnID: String?
    }

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

    static func parseFile(
        _ url: URL,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> SessionSummary? {
        let decoder = JSONDecoder()

        var timestamp: Date?
        var cwd: String?
        var sessionID: String?
        var agentNickname: String?
        var sessionTitle: String?
        var turnID: String?
        var isTopLevel = true
        var tokens = 0
        var longestTaskDuration: TimeInterval = 0
        var state: ProjectRunState = .completed
        var updatedAt = Date.distantPast
        var weeklyUsedPercent: Double?
        var weeklyLimitID: String?
        var weeklyResetsAt: Date?
        var weeklyQuotaUpdatedAt: Date?

        try forEachSummaryLine(in: url) { line in
            guard isRelevant(line),
                  let envelope = try? decoder.decode(CodexEnvelope.self, from: line) else {
                return
            }

            let payload = envelope.payload
            switch payload.type ?? envelope.type {
            case "session_meta":
                cwd = payload.cwd
                timestamp = payload.timestamp.flatMap(parseTimestamp)
                sessionID = payload.id ?? payload.sessionID
                agentNickname = payload.agentNickname
                let hasParent = !(payload.parentThreadID ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
                isTopLevel = !hasParent && !(payload.source?.isInternal ?? false)
            case "user_message":
                if sessionTitle == nil {
                    sessionTitle = readableSessionTitle(from: payload.message)
                }
                state = .running
                turnID = nil
                updatedAt = envelope.timestamp.flatMap(parseTimestamp) ?? updatedAt
            case "task_started":
                state = .running
                turnID = payload.turnID
                updatedAt = payload.startedAt.map(Date.init(timeIntervalSince1970:)) ?? updatedAt
            case "task_complete":
                state = .completed
                turnID = payload.turnID
                longestTaskDuration = max(longestTaskDuration, (payload.durationMS ?? 0) / 1_000)
                updatedAt = payload.completedAt.map(Date.init(timeIntervalSince1970:)) ?? updatedAt
            case "turn_aborted":
                state = .failed
                turnID = payload.turnID
                longestTaskDuration = max(longestTaskDuration, (payload.durationMS ?? 0) / 1_000)
                updatedAt = payload.completedAt.map(Date.init(timeIntervalSince1970:)) ?? updatedAt
            case "token_count":
                tokens = payload.info?.totalTokenUsage?.totalTokens ?? tokens
                if let weeklyWindow = payload.rateLimits?.weeklyWindow {
                    weeklyUsedPercent = weeklyWindow.usedPercent
                    weeklyLimitID = payload.rateLimits?.limitID
                    weeklyResetsAt = weeklyWindow.resetsAt
                        .map(Date.init(timeIntervalSince1970:))
                    weeklyQuotaUpdatedAt = envelope.timestamp.flatMap(parseTimestamp)
                }
            default:
                break
            }
        }

        if let lifecycle = try latestLifecycleEvent(in: url) {
            state = lifecycle.state
            if let lifecycleUpdatedAt = lifecycle.updatedAt {
                updatedAt = lifecycleUpdatedAt
            }
            longestTaskDuration = max(longestTaskDuration, lifecycle.duration)
            turnID = lifecycle.turnID
        }

        guard let timestamp, let cwd else {
            return nil
        }

        return SessionSummary(
            date: timestamp,
            projectName: projectName(for: cwd, homeDirectory: homeDirectory),
            sessionID: sessionID ?? url.deletingPathExtension().lastPathComponent,
            agentNickname: agentNickname,
            sessionTitle: sessionTitle,
            turnID: turnID,
            isTopLevel: isTopLevel,
            totalTokens: tokens,
            longestTaskDuration: longestTaskDuration,
            state: state,
            updatedAt: updatedAt == .distantPast ? timestamp : updatedAt,
            weeklyUsedPercent: weeklyUsedPercent,
            weeklyLimitID: weeklyLimitID,
            weeklyResetsAt: weeklyResetsAt,
            weeklyQuotaUpdatedAt: weeklyQuotaUpdatedAt
        )
    }

    static func projectName(for cwd: String, homeDirectory: URL) -> String? {
        let directory = URL(fileURLWithPath: cwd, isDirectory: true).standardizedFileURL
        let home = homeDirectory.standardizedFileURL
        guard directory != home else { return nil }

        let name = directory.lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private static func isRelevant(_ line: Data) -> Bool {
        guard let prefix = String(data: line.prefix(2_048), encoding: .utf8) else {
            return false
        }
        return prefix.contains("\"type\":\"session_meta\"") ||
            prefix.contains("\"type\":\"task_started\"") ||
            prefix.contains("\"type\":\"task_complete\"") ||
            prefix.contains("\"type\":\"turn_aborted\"") ||
            prefix.contains("\"type\":\"user_message\"") ||
            prefix.contains("\"type\":\"token_count\"")
    }

    private static func readableSessionTitle(from message: String?) -> String? {
        guard let message else { return nil }
        let title = message
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.hasPrefix("<") && !$0.hasPrefix("# AGENTS") }
        guard let title else { return nil }
        return String(title.prefix(24))
    }

    private static func parseTimestamp(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        return ISO8601DateFormatter().date(from: value)
    }

    private static func latestLifecycleEvent(
        in url: URL,
        chunkSize: Int = 64 * 1_024
    ) throws -> LifecycleEvent? {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        var offset = values.fileSize ?? 0
        guard offset > 0 else { return nil }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let decoder = JSONDecoder()
        var trailingPartialLine = Data()

        while offset > 0 {
            let readSize = min(chunkSize, offset)
            offset -= readSize
            try handle.seek(toOffset: UInt64(offset))

            var block = try handle.read(upToCount: readSize) ?? Data()
            block.append(trailingPartialLine)
            let lines = block.split(
                separator: 0x0A,
                omittingEmptySubsequences: false
            )

            let firstCompleteLine = offset > 0 ? 1 : 0
            if firstCompleteLine < lines.count {
                for line in lines[firstCompleteLine...].reversed() {
                    let data = Data(line)
                    guard isLifecycleLine(data),
                          let envelope = try? decoder.decode(CodexEnvelope.self, from: data),
                          let lifecycle = lifecycleEvent(from: envelope) else {
                        continue
                    }
                    return lifecycle
                }
            }

            trailingPartialLine = offset > 0
                ? lines.first.map { Data($0) } ?? Data()
                : Data()
        }

        return nil
    }

    private static func isLifecycleLine(_ line: Data) -> Bool {
        guard let prefix = String(data: line.prefix(2_048), encoding: .utf8) else {
            return false
        }
        return prefix.contains("\"type\":\"task_started\"") ||
            prefix.contains("\"type\":\"task_complete\"") ||
            prefix.contains("\"type\":\"turn_aborted\"") ||
            prefix.contains("\"type\":\"user_message\"")
    }

    private static func lifecycleEvent(from envelope: CodexEnvelope) -> LifecycleEvent? {
        let payload = envelope.payload
        switch payload.type ?? envelope.type {
        case "user_message":
            return LifecycleEvent(
                state: .running,
                updatedAt: envelope.timestamp.flatMap(parseTimestamp),
                duration: 0,
                turnID: nil
            )
        case "task_started":
            return LifecycleEvent(
                state: .running,
                updatedAt: payload.startedAt.map(Date.init(timeIntervalSince1970:)),
                duration: 0,
                turnID: payload.turnID
            )
        case "task_complete":
            return LifecycleEvent(
                state: .completed,
                updatedAt: payload.completedAt.map(Date.init(timeIntervalSince1970:)),
                duration: (payload.durationMS ?? 0) / 1_000,
                turnID: payload.turnID
            )
        case "turn_aborted":
            return LifecycleEvent(
                state: .failed,
                updatedAt: payload.completedAt.map(Date.init(timeIntervalSince1970:)),
                duration: (payload.durationMS ?? 0) / 1_000,
                turnID: payload.turnID
            )
        default:
            return nil
        }
    }

    static func forEachLine(
        in url: URL,
        chunkSize: Int = 64 * 1_024,
        maximumLineSize: Int = 16 * 1_024 * 1_024,
        body: (Data) -> Void
    ) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let newline = Data([0x0A])
        var buffer = Data()
        var discardingOversizedLine = false

        while let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty {
            var unread = chunk

            if discardingOversizedLine {
                guard let newlineRange = unread.firstRange(of: newline) else {
                    continue
                }
                unread.removeSubrange(unread.startIndex..<newlineRange.upperBound)
                discardingOversizedLine = false
            }

            buffer.append(unread)
            while let newlineRange = buffer.firstRange(of: newline) {
                let line = Data(buffer[..<newlineRange.lowerBound])
                body(line)
                buffer.removeSubrange(buffer.startIndex..<newlineRange.upperBound)
            }

            if buffer.count > maximumLineSize {
                buffer.removeAll(keepingCapacity: false)
                discardingOversizedLine = true
            }
        }

        if !discardingOversizedLine, !buffer.isEmpty {
            body(buffer)
        }
    }

    private static func forEachSummaryLine(
        in url: URL,
        body: (Data) -> Void
    ) throws {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        let fileSize = values.fileSize ?? 0
        let fullScanThreshold = 4 * 1_024 * 1_024
        guard fileSize > fullScanThreshold else {
            try forEachLine(in: url, body: body)
            return
        }

        let segmentSize = 1 * 1_024 * 1_024
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let head = try handle.read(upToCount: segmentSize) ?? Data()
        forEachCompleteLine(
            in: head,
            skippingInitialPartialLine: false,
            includeTrailingLine: false,
            body: body
        )

        let tailOffset = max(0, fileSize - segmentSize)
        try handle.seek(toOffset: UInt64(tailOffset))
        let tail = try handle.readToEnd() ?? Data()
        forEachCompleteLine(
            in: tail,
            skippingInitialPartialLine: tailOffset > 0,
            includeTrailingLine: true,
            body: body
        )
    }

    private static func forEachCompleteLine(
        in data: Data,
        skippingInitialPartialLine: Bool,
        includeTrailingLine: Bool,
        body: (Data) -> Void
    ) {
        var start = data.startIndex
        if skippingInitialPartialLine {
            guard let newline = data[start...].firstIndex(of: 0x0A) else { return }
            start = data.index(after: newline)
        }

        while start < data.endIndex,
              let newline = data[start...].firstIndex(of: 0x0A) {
            body(Data(data[start..<newline]))
            start = data.index(after: newline)
        }

        if includeTrailingLine, start < data.endIndex {
            body(Data(data[start..<data.endIndex]))
        }
    }
}

final class IncrementalSessionScanner: @unchecked Sendable {
    typealias Parser = @Sendable (URL) throws -> SessionSummary?

    private struct Fingerprint: Equatable {
        let size: Int
        let modificationDate: Date
    }

    private struct Entry {
        let fingerprint: Fingerprint
        let summary: SessionSummary?
    }

    private let parser: Parser
    private let lock = NSLock()
    private var entries: [String: Entry] = [:]

    init(parser: @escaping Parser = { url in try SessionScanner.parseFile(url) }) {
        self.parser = parser
    }

    func scan(root: URL) async throws -> [SessionSummary] {
        try await Task.detached(priority: .utility) { [self] in
            try scanSynchronously(root: root)
        }.value
    }

    private func scanSynchronously(root: URL) throws -> [SessionSummary] {
        lock.lock()
        defer { lock.unlock() }

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .fileSizeKey,
                .contentModificationDateKey
            ],
            options: [.skipsHiddenFiles]
        ) else {
            entries = [:]
            return []
        }

        var nextEntries: [String: Entry] = [:]
        var summaries: [SessionSummary] = []

        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let values = try url.resourceValues(forKeys: [
                .isRegularFileKey,
                .fileSizeKey,
                .contentModificationDateKey
            ])
            guard values.isRegularFile == true,
                  let size = values.fileSize,
                  let modificationDate = values.contentModificationDate else {
                continue
            }

            let fingerprint = Fingerprint(size: size, modificationDate: modificationDate)
            let entry: Entry
            if let cached = entries[url.path], cached.fingerprint == fingerprint {
                entry = cached
            } else {
                entry = Entry(fingerprint: fingerprint, summary: try parser(url))
            }
            nextEntries[url.path] = entry
            if let summary = entry.summary {
                summaries.append(summary)
            }
        }

        entries = nextEntries
        return summaries
    }
}
