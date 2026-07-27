import AppKit
import SwiftUI
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

    func testReferenceActivityGridBuildsSixteenWeeks() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 29)
        )!
        let days = MenuActivityGrid.days(
            from: [],
            calendar: calendar,
            today: today
        )

        XCTAssertEqual(days.count, 112)
        XCTAssertEqual(calendar.component(.weekday, from: days[0].date), 2)
    }

    func testDailyTokenBarsKeepLastSevenCalendarDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let days = (0..<9).map {
            UsageDay(
                date: Date(timeIntervalSince1970: Double($0 * 86_400)),
                tokens: ($0 + 1) * 100,
                sessions: 1
            )
        }

        XCTAssertEqual(
            MenuDailyTokenBarPlan.make(
                days: days,
                calendar: calendar,
                today: days.last!.date
            ).map(\.tokens),
            [300, 400, 500, 600, 700, 800, 900]
        )
    }

    func testDailyTokenBarsFillMissingCalendarDaysWithZero() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 27)
        )!
        let input = [
            UsageDay(
                date: calendar.date(byAdding: .day, value: -6, to: today)!,
                tokens: 100,
                sessions: 1
            ),
            UsageDay(
                date: calendar.date(byAdding: .day, value: -4, to: today)!,
                tokens: 300,
                sessions: 1
            ),
            UsageDay(date: today, tokens: 700, sessions: 1)
        ]

        XCTAssertEqual(
            MenuDailyTokenBarPlan.make(
                days: input,
                calendar: calendar,
                today: today
            ).map(\.tokens),
            [100, 0, 300, 0, 0, 0, 700]
        )
    }

    @MainActor
    func testMenuActivityHoverReadoutKeepsTheSameSize() {
        let day = UsageDay(
            date: Date(timeIntervalSince1970: 0),
            tokens: 100,
            sessions: 1
        )
        let idle = NSHostingView(
            rootView: MenuActivityHoverReadout(day: nil)
        ).fittingSize
        let hovered = NSHostingView(
            rootView: MenuActivityHoverReadout(day: day)
        ).fittingSize

        XCTAssertEqual(idle, CGSize(width: 158, height: 9))
        XCTAssertEqual(hovered, idle)
    }

    func testOldActivityCellExitDoesNotClearNewHoverSelection() {
        let oldDay = UsageDay(
            date: Date(timeIntervalSince1970: 0),
            tokens: 100,
            sessions: 1
        )
        let newDay = UsageDay(
            date: Date(timeIntervalSince1970: 86_400),
            tokens: 200,
            sessions: 2
        )

        let selected = MenuActivityHoverSelection.next(
            current: newDay,
            day: oldDay,
            isHovered: false
        )

        XCTAssertEqual(selected, newDay)
    }
}
