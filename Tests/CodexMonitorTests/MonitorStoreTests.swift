import XCTest
@testable import CodexMonitor

@MainActor
final class MonitorStoreTests: XCTestCase {
    func testRepeatedRefreshRequestsAreCoalesced() async throws {
        let harness = ScannerHarness(sessions: [sampleSummary])
        let store = MonitorStore(
            root: URL(fileURLWithPath: "/tmp/sessions"),
            debounceNanoseconds: 10_000_000,
            scanner: { _ in try await harness.scan() }
        )

        for _ in 0..<5 {
            store.requestRefresh()
        }
        try await Task.sleep(for: .milliseconds(80))

        let invocationCount = await harness.count()
        XCTAssertEqual(invocationCount, 1)
        XCTAssertEqual(store.snapshot.lifetimeTokens, 42)
        XCTAssertFalse(store.isLoading)
    }

    func testScannerFailureKeepsLastGoodSnapshot() async throws {
        let harness = ScannerHarness(sessions: [sampleSummary])
        let store = MonitorStore(
            root: URL(fileURLWithPath: "/tmp/sessions"),
            debounceNanoseconds: 10_000_000,
            scanner: { _ in try await harness.scan() }
        )

        store.requestRefresh()
        try await Task.sleep(for: .milliseconds(80))
        await harness.setFailure(true)
        store.requestRefresh()
        try await Task.sleep(for: .milliseconds(80))

        XCTAssertEqual(store.snapshot.lifetimeTokens, 42)
        XCTAssertEqual(store.errorMessage, "数据可能已过期")
    }

    func testWatcherRejectsMissingDirectory() {
        let watcher = SessionDirectoryWatcher(
            root: URL(fileURLWithPath: "/definitely/missing/codex-sessions"),
            onChange: {}
        )

        XCTAssertFalse(watcher.start())
    }

    private var sampleSummary: SessionSummary {
        SessionSummary(
            date: Date(timeIntervalSince1970: 100),
            projectName: "Sample",
            totalTokens: 42,
            longestTaskDuration: 0,
            state: .running,
            updatedAt: Date(timeIntervalSince1970: 101),
            weeklyUsedPercent: 25,
            weeklyResetsAt: nil
        )
    }
}

private actor ScannerHarness {
    enum Failure: Error { case requested }

    private let sessions: [SessionSummary]
    private var shouldFail = false
    private(set) var invocationCount = 0

    init(sessions: [SessionSummary]) {
        self.sessions = sessions
    }

    func setFailure(_ value: Bool) {
        shouldFail = value
    }

    func scan() throws -> [SessionSummary] {
        invocationCount += 1
        if shouldFail { throw Failure.requested }
        return sessions
    }

    func count() -> Int {
        invocationCount
    }
}
