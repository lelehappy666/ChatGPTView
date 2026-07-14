import XCTest
@testable import CodexMonitor

@MainActor
final class MonitorStoreTests: XCTestCase {
    func testIncrementalScannerReusesUnchangedFileSummary() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("session.jsonl")
        try Data("{}\n".utf8).write(to: file)

        let counter = ParseCounter()
        let summary = sampleSummary
        let scanner = IncrementalSessionScanner { _ in
            counter.increment()
            return summary
        }

        let first = try await scanner.scan(root: root)
        let second = try await scanner.scan(root: root)

        XCTAssertEqual(first, [sampleSummary])
        XCTAssertEqual(second, [sampleSummary])
        XCTAssertEqual(counter.value, 1)
    }

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
        XCTAssertEqual(store.refreshState, .refreshing)
        try await Task.sleep(for: .milliseconds(80))

        let invocationCount = await harness.count()
        XCTAssertEqual(invocationCount, 1)
        XCTAssertEqual(store.snapshot.lifetimeTokens, 42)
        XCTAssertFalse(store.isLoading)
        XCTAssertEqual(store.refreshState, .updated)
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
        XCTAssertEqual(store.refreshState, .failed)
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

private final class ParseCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func increment() {
        lock.withLock { count += 1 }
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
