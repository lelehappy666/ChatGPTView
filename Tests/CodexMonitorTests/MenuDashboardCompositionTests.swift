import XCTest
@testable import CodexMonitor

final class MenuDashboardCompositionTests: XCTestCase {
    func testListsEachDashboardSectionOnceInDisplayOrder() {
        XCTAssertEqual(
            MenuDashboardComposition.sections,
            [.weeklyQuota, .dailyActivity, .projectAnalytics, .statistics, .github]
        )
        XCTAssertEqual(Set(MenuDashboardComposition.sections).count, 5)
    }

    func testTodayActivityIsEmptyWhenOnlyPreviousDaysHaveUsage() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let yesterday = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 26, hour: 12)
        )!
        let today = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 27, hour: 12)
        )!

        let activity = MenuDailyActivityPresentation.todayActivity(
            in: [UsageDay(date: yesterday, tokens: 900, sessions: 3)],
            at: today,
            calendar: calendar
        )

        XCTAssertNil(activity)
    }

    func testProjectAnalyticsBarPlanPreservesRankingAndNormalizesHeightsByMaximumTokens() {
        let rows = [
            ProjectAnalyticsRow(
                id: "a", name: "A", tokens: 100,
                sessions: 2, activeDays: 1, share: 2.0 / 3.0
            ),
            ProjectAnalyticsRow(
                id: "b", name: "B", tokens: 50,
                sessions: 1, activeDays: 1, share: 1.0 / 3.0
            )
        ]

        let bars = ProjectAnalyticsBarPlan.make(rows: rows)

        XCTAssertEqual(bars.map(\.id), ["a", "b"])
        XCTAssertEqual(bars.map(\.relativeHeight), [1.0, 0.5])
    }
}
