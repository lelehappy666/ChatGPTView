import XCTest
@testable import CodexMonitor

final class JSONLDecoderTests: XCTestCase {
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

    private func fixtureURL(named name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
            .appendingPathExtension("jsonl")
    }
}
