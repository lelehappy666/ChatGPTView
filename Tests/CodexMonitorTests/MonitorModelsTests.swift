import XCTest
@testable import CodexMonitor

final class MonitorModelsTests: XCTestCase {
    func testProjectPriorityOrdersFailedBeforeRunningBeforeCompleted() {
        let items = [
            ProjectActivity(name: "Done", state: .completed, updatedAt: .distantPast),
            ProjectActivity(name: "Run", state: .running, updatedAt: .now),
            ProjectActivity(name: "Fail", state: .failed, updatedAt: .now)
        ]

        XCTAssertEqual(items.sortedForMenu.map(\.name), ["Fail", "Run", "Done"])
    }

    func testEmptySnapshotUsesUnavailableWeeklyQuota() {
        XCTAssertNil(MonitorSnapshot.empty.weeklyQuota.remainingPercent)
    }
}
