import XCTest
@testable import CodexMonitor

final class JSONLDecoderTests: XCTestCase {
    func testSessionMetadataExtractsStableIdentityAndNickname() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jsonl")
        defer { try? FileManager.default.removeItem(at: url) }
        let contents = """
        {"type":"session_meta","payload":{"type":"session_meta","id":"session-123","agent_nickname":"Carson","timestamp":"2026-07-14T06:36:17Z","cwd":"/Users/test/Projects/Replaypoker"}}
        {"type":"event_msg","payload":{"type":"task_started","started_at":1784010977}}
        """
        try contents.write(to: url, atomically: true, encoding: .utf8)

        let summary = try XCTUnwrap(SessionScanner.parseFile(url))

        XCTAssertEqual(summary.sessionID, "session-123")
        XCTAssertEqual(summary.agentNickname, "Carson")
    }

    func testSessionIdentityFallsBackToFileName() throws {
        let summary = try XCTUnwrap(
            SessionScanner.parseFile(fixtureURL(named: "session-running"))
        )

        XCTAssertEqual(summary.sessionID, "session-running")
        XCTAssertNil(summary.agentNickname)
    }

    func testHomeDirectoryDoesNotBecomeProjectName() {
        let home = URL(fileURLWithPath: "/Users/lele", isDirectory: true)

        XCTAssertNil(SessionScanner.projectName(for: "/Users/lele", homeDirectory: home))
        XCTAssertNil(SessionScanner.projectName(for: "/Users/lele/", homeDirectory: home))
        XCTAssertEqual(
            SessionScanner.projectName(
                for: "/Users/lele/Desktop/大丰数艺/Codex额度",
                homeDirectory: home
            ),
            "Codex额度"
        )
    }

    func testRunningFixtureExtractsWeeklyQuotaAndProjectName() throws {
        let summary = try SessionScanner.parseFile(fixtureURL(named: "session-running"))

        XCTAssertEqual(summary?.projectName, "CodexMonitor")
        XCTAssertEqual(summary?.totalTokens, 142_000)
        XCTAssertEqual(summary?.weeklyUsedPercent, 25)
        XCTAssertEqual(summary?.state, .running)
    }

    func testAbortedFixtureIsFailedAndKeepsDuration() throws {
        let summary = try SessionScanner.parseFile(fixtureURL(named: "session-failed"))

        XCTAssertEqual(summary?.projectName, "DataSync")
        XCTAssertEqual(summary?.state, .failed)
        XCTAssertEqual(summary?.longestTaskDuration, 3_600)
    }

    func testSecondaryWeeklyWindowIsParsedFromLargeSessionFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jsonl")
        defer { try? FileManager.default.removeItem(at: url) }

        let padding = String(repeating: "x", count: 5 * 1_024 * 1_024)
        let contents = """
        {"timestamp":"2026-07-14T03:06:01.253Z","type":"session_meta","payload":{"timestamp":"2026-07-14T03:06:01.118Z","cwd":"/Users/tester/Projects/RealProject"}}
        {"timestamp":"2026-07-14T03:06:02.000Z","type":"response_item","payload":{"type":"message","content":"\(padding)"}}
        {"timestamp":"2026-07-14T03:06:03.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":321000}},"rate_limits":{"primary":{"used_percent":88,"window_minutes":300,"resets_at":1783999000},"secondary":{"used_percent":31,"window_minutes":10080,"resets_at":1784510985}}}}
        """
        try contents.write(to: url, atomically: true, encoding: .utf8)

        let lines = contents.split(separator: "\n")
        let metadata = try JSONDecoder().decode(CodexEnvelope.self, from: Data(lines[0].utf8))
        let quota = try JSONDecoder().decode(CodexEnvelope.self, from: Data(lines[2].utf8))
        XCTAssertEqual(metadata.payload.cwd, "/Users/tester/Projects/RealProject")
        XCTAssertEqual(quota.payload.rateLimits?.weeklyWindow?.usedPercent, 31)

        var streamedLines = 0
        try SessionScanner.forEachLine(in: url) { _ in streamedLines += 1 }
        XCTAssertEqual(streamedLines, 3)

        let summary = try SessionScanner.parseFile(url)

        XCTAssertEqual(summary?.projectName, "RealProject")
        XCTAssertEqual(summary?.totalTokens, 321_000)
        XCTAssertEqual(summary?.weeklyUsedPercent, 31)
        XCTAssertEqual(summary?.weeklyResetsAt, Date(timeIntervalSince1970: 1_784_510_985))
    }

    private func fixtureURL(named name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
            .appendingPathExtension("jsonl")
    }
}
