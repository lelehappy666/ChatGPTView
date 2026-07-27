import XCTest
@testable import CodexMonitor

final class VisualFeedbackTests: XCTestCase {
    func testRunningAccentUsesOpaqueHighContrastOrange() {
        XCTAssertEqual(RGBToken.runningAccent.hex, "FF9F0A")
    }

    func testActivityHoverPresentationHasNoDelay() {
        XCTAssertEqual(ActivityTooltip.presentationDelayMilliseconds, 0)
    }

    func testActivityTooltipIncludesDateTokensAndSessions() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 7, day: 14))!
        let day = UsageDay(date: date, tokens: 142_000, sessions: 3)

        XCTAssertEqual(
            ActivityTooltip.text(for: day, calendar: calendar),
            "7月14日 · 14.2 万 Token · 3 个会话"
        )
    }

    func testEmptyActivityTooltipStillIncludesDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 7, day: 13))!
        let day = UsageDay(date: date, tokens: 0, sessions: 0)

        XCTAssertEqual(
            ActivityTooltip.text(for: day, calendar: calendar),
            "7月13日 · 无活动"
        )
    }

    func testActivityGridFillsMissingCalendarDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(from: DateComponents(year: 2026, month: 7, day: 14))!
        let july12 = calendar.date(byAdding: .day, value: -2, to: today)!
        let input = [
            UsageDay(date: july12, tokens: 12_000, sessions: 1),
            UsageDay(date: today, tokens: 24_000, sessions: 2)
        ]

        let grid = ActivityGrid.days(from: input, calendar: calendar, today: today)

        XCTAssertEqual(grid.count, 56)
        XCTAssertEqual(grid.suffix(3).map(\.tokens), [12_000, 0, 24_000])
        XCTAssertEqual(grid.suffix(3).map(\.sessions), [1, 0, 2])
    }

    func testCompactActivityHeatmapIsShorterThanStandardLayout() {
        let standard = ActivityHeatmapMetrics.make(density: .standard)
        let compact = ActivityHeatmapMetrics.make(density: .compact)

        XCTAssertLessThan(compact.totalHeight, standard.totalHeight)
        XCTAssertLessThan(compact.width, standard.width)
        XCTAssertEqual(compact.rowCount, 7)
    }
}
