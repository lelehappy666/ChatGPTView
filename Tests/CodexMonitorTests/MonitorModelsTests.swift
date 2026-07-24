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

    func testQuotaFreshnessShowsOnlyRecentValues() {
        let eventTime = Date(timeIntervalSince1970: 1_000)
        let quota = WeeklyQuota(
            remainingPercent: 34,
            resetsAt: nil,
            updatedAt: eventTime
        )

        XCTAssertEqual(
            QuotaFreshnessPolicy.visibleRemainingPercent(
                for: quota,
                at: eventTime.addingTimeInterval(299)
            ),
            34
        )
        XCTAssertEqual(
            QuotaFreshnessPolicy.visibleRemainingPercent(
                for: quota,
                at: eventTime.addingTimeInterval(300)
            ),
            34
        )
        XCTAssertNil(
            QuotaFreshnessPolicy.visibleRemainingPercent(
                for: quota,
                at: eventTime.addingTimeInterval(301)
            )
        )
    }

    func testQuotaFreshnessRejectsMissingTimestampAndLargeFutureSkew() {
        let now = Date(timeIntervalSince1970: 2_000)
        XCTAssertNil(
            QuotaFreshnessPolicy.visibleRemainingPercent(
                for: WeeklyQuota(remainingPercent: 34, resetsAt: nil),
                at: now
            )
        )
        XCTAssertEqual(
            QuotaFreshnessPolicy.visibleRemainingPercent(
                for: WeeklyQuota(
                    remainingPercent: 34,
                    resetsAt: nil,
                    updatedAt: now.addingTimeInterval(60)
                ),
                at: now
            ),
            34
        )
        XCTAssertNil(
            QuotaFreshnessPolicy.visibleRemainingPercent(
                for: WeeklyQuota(
                    remainingPercent: 34,
                    resetsAt: nil,
                    updatedAt: now.addingTimeInterval(61)
                ),
                at: now
            )
        )
    }

    func testQuotaFreshnessRecoversWhenNewEventArrives() {
        let now = Date(timeIntervalSince1970: 3_000)
        let stale = WeeklyQuota(
            remainingPercent: 44,
            resetsAt: nil,
            updatedAt: now.addingTimeInterval(-301)
        )
        let refreshed = WeeklyQuota(
            remainingPercent: 34,
            resetsAt: nil,
            updatedAt: now
        )

        XCTAssertNil(
            QuotaFreshnessPolicy.visibleRemainingPercent(for: stale, at: now)
        )
        XCTAssertEqual(
            QuotaFreshnessPolicy.visibleRemainingPercent(for: refreshed, at: now),
            34
        )
    }
}
