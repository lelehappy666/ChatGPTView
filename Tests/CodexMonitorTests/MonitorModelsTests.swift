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

    func testQuotaDisplayStateKeepsLastKnownValueAfterFreshWindow() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let quota = WeeklyQuota(
            remainingPercent: 77,
            resetsAt: now.addingTimeInterval(6 * 86_400),
            updatedAt: now.addingTimeInterval(-2_600)
        )

        XCTAssertEqual(
            QuotaFreshnessPolicy.displayState(for: quota, at: now),
            .lastKnown(remainingPercent: 77)
        )
    }

    func testQuotaDisplayStateDistinguishesMissingAndFreshValues() {
        let now = Date(timeIntervalSince1970: 1_000_000)

        XCTAssertEqual(
            QuotaFreshnessPolicy.displayState(
                for: WeeklyQuota(remainingPercent: nil, resetsAt: nil),
                at: now
            ),
            .unavailable
        )
        XCTAssertEqual(
            QuotaFreshnessPolicy.displayState(
                for: WeeklyQuota(
                    remainingPercent: 76,
                    resetsAt: nil,
                    updatedAt: now.addingTimeInterval(-60)
                ),
                at: now
            ),
            .fresh(remainingPercent: 76)
        )
    }

    func testQuotaDisplayStateRejectsValueAfterItsResetDate() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(
            QuotaFreshnessPolicy.displayState(
                for: WeeklyQuota(
                    remainingPercent: 77,
                    resetsAt: now.addingTimeInterval(-1),
                    updatedAt: now.addingTimeInterval(-60)
                ),
                at: now
            ),
            .unavailable
        )
    }
}
