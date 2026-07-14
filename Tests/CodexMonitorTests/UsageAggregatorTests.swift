import XCTest
@testable import CodexMonitor

final class UsageAggregatorTests: XCTestCase {
    func testAggregationUsesNewestWeeklyWindowAndGroupsDays() {
        let dayOne = date(2026, 7, 13, 9)
        let dayTwo = date(2026, 7, 14, 12)
        let sessions = [
            summary(
                date: dayOne,
                project: "Active",
                tokens: 100,
                state: .completed,
                updatedAt: date(2026, 7, 13, 10)
            ),
            summary(
                date: dayTwo,
                project: "Active",
                tokens: 50,
                state: .running,
                updatedAt: date(2026, 7, 14, 12),
                weeklyUsed: 25
            ),
            summary(
                date: dayTwo,
                project: "Broken",
                tokens: 300,
                state: .failed,
                updatedAt: date(2026, 7, 14, 13)
            )
        ]

        let snapshot = UsageAggregator.makeSnapshot(
            sessions: sessions,
            now: dayTwo,
            calendar: utcCalendar
        )

        XCTAssertEqual(snapshot.weeklyQuota.remainingPercent, 75)
        XCTAssertEqual(snapshot.dailyActivity.map(\.tokens), [100, 350])
        XCTAssertEqual(snapshot.lifetimeTokens, 450)
        XCTAssertEqual(snapshot.peakTokens, 300)
        XCTAssertEqual(snapshot.currentStreakDays, 2)
        XCTAssertEqual(snapshot.longestStreakDays, 2)
        XCTAssertEqual(snapshot.projects.map(\.name), ["Broken", "Active"])
    }

    func testCompletedProjectExpiresAfterThirtyMinutes() {
        let now = date(2026, 7, 14, 12)
        let oldCompleted = summary(
            date: now,
            project: "Old",
            tokens: 10,
            state: .completed,
            updatedAt: now.addingTimeInterval(-1_801)
        )

        let snapshot = UsageAggregator.makeSnapshot(
            sessions: [oldCompleted],
            now: now,
            calendar: utcCalendar
        )

        XCTAssertTrue(snapshot.projects.isEmpty)
    }

    func testUnnamedSessionContributesUsageWithoutCreatingProject() {
        let now = date(2026, 7, 14, 12)
        let unnamed = summary(
            date: now,
            project: nil,
            tokens: 420,
            state: .running,
            updatedAt: now
        )

        let snapshot = UsageAggregator.makeSnapshot(
            sessions: [unnamed],
            now: now,
            calendar: utcCalendar
        )

        XCTAssertEqual(snapshot.lifetimeTokens, 420)
        XCTAssertEqual(snapshot.dailyActivity.map(\.tokens), [420])
        XCTAssertTrue(snapshot.projects.isEmpty)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        utcCalendar.date(from: DateComponents(
            timeZone: utcCalendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }

    private func summary(
        date: Date,
        project: String?,
        tokens: Int,
        state: ProjectRunState,
        updatedAt: Date,
        weeklyUsed: Double? = nil
    ) -> SessionSummary {
        SessionSummary(
            date: date,
            projectName: project,
            totalTokens: tokens,
            longestTaskDuration: 0,
            state: state,
            updatedAt: updatedAt,
            weeklyUsedPercent: weeklyUsed,
            weeklyResetsAt: nil
        )
    }
}
