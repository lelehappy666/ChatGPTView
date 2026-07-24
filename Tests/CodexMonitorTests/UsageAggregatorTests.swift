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

    func testCanonicalCodexQuotaWinsOverNewerModelSpecificQuota() {
        let now = date(2026, 7, 14, 12)
        let sessions = [
            summary(
                date: now,
                project: "主会话",
                tokens: 100,
                state: .running,
                updatedAt: now.addingTimeInterval(-5),
                weeklyUsed: 70,
                weeklyLimitID: "codex"
            ),
            summary(
                date: now,
                project: "Spark会话",
                tokens: 100,
                state: .running,
                updatedAt: now,
                weeklyUsed: 0,
                weeklyLimitID: "codex_bengalfox"
            )
        ]

        let snapshot = UsageAggregator.makeSnapshot(
            sessions: sessions,
            now: now,
            calendar: utcCalendar
        )

        XCTAssertEqual(snapshot.weeklyQuota.remainingPercent, 30)
    }

    func testNewestQuotaEventWinsEvenWhenOlderSessionRemainsActive() {
        let now = date(2026, 7, 21, 12)
        let sessions = [
            summary(
                date: now,
                project: "旧会话",
                tokens: 100,
                state: .running,
                updatedAt: now,
                weeklyUsed: 16,
                weeklyLimitID: "codex",
                weeklyQuotaUpdatedAt: now.addingTimeInterval(-120)
            ),
            summary(
                date: now,
                project: "新额度",
                tokens: 100,
                state: .running,
                updatedAt: now.addingTimeInterval(-60),
                weeklyUsed: 2,
                weeklyLimitID: "codex",
                weeklyQuotaUpdatedAt: now.addingTimeInterval(-30)
            )
        ]

        let snapshot = UsageAggregator.makeSnapshot(
            sessions: sessions,
            now: now,
            calendar: utcCalendar
        )

        XCTAssertEqual(snapshot.weeklyQuota.remainingPercent, 98)
        XCTAssertEqual(
            snapshot.weeklyQuota.updatedAt,
            now.addingTimeInterval(-30)
        )
    }

    func testAllProjectStatesExpireAfterSixtySeconds() {
        let now = date(2026, 7, 14, 12)
        let staleProjects = [
            summary(
                date: now,
                project: "运行",
                tokens: 10,
                state: .running,
                updatedAt: now.addingTimeInterval(-60)
            ),
            summary(
                date: now,
                project: "完成",
                tokens: 10,
                state: .completed,
                updatedAt: now.addingTimeInterval(-60)
            ),
            summary(
                date: now,
                project: "报错",
                tokens: 10,
                state: .failed,
                updatedAt: now.addingTimeInterval(-60)
            )
        ]

        let snapshot = UsageAggregator.makeSnapshot(
            sessions: staleProjects,
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

    func testInternalSessionKeepsUsageAndHierarchyInAggregatedSnapshot() throws {
        let now = date(2026, 7, 15, 10)
        let sessions = [
            summary(
                date: now,
                project: "Replaypoker(ios)",
                tokens: 1_000,
                state: .running,
                updatedAt: now,
                sessionID: "root"
            ),
            summary(
                date: now,
                project: "Replaypoker(ios)",
                tokens: 250,
                state: .completed,
                updatedAt: now.addingTimeInterval(1),
                sessionID: "Epicurus",
                isTopLevel: false
            )
        ]

        let snapshot = UsageAggregator.makeSnapshot(
            sessions: sessions,
            now: now.addingTimeInterval(1),
            calendar: utcCalendar
        )

        XCTAssertEqual(snapshot.lifetimeTokens, 1_250)
        XCTAssertEqual(snapshot.dailyActivity.count, 1)
        XCTAssertEqual(snapshot.dailyActivity.first?.sessions, 2)
        let child = try XCTUnwrap(snapshot.sessions.first { $0.id == "Epicurus" })
        XCTAssertFalse(child.isTopLevel)
    }

    func testSameProjectKeepsRunningAndCompletedSessionsIndependent() {
        let now = date(2026, 7, 14, 12)
        let sessions = [
            summary(
                date: now.addingTimeInterval(-600),
                project: "Replaypoker",
                tokens: 10,
                state: .running,
                updatedAt: now.addingTimeInterval(-10),
                sessionID: "running-session",
                agentNickname: "Atlas"
            ),
            summary(
                date: now.addingTimeInterval(-300),
                project: "Replaypoker",
                tokens: 20,
                state: .completed,
                updatedAt: now.addingTimeInterval(-5),
                sessionID: "completed-session",
                agentNickname: "Carson"
            )
        ]

        let snapshot = UsageAggregator.makeSnapshot(
            sessions: sessions,
            now: now,
            calendar: utcCalendar
        )

        XCTAssertEqual(snapshot.sessions.map(\.id), ["running-session", "completed-session"])
        XCTAssertEqual(snapshot.sessions.map(\.state), [.running, .completed])
        XCTAssertEqual(snapshot.sessions.map(\.displayName), ["Atlas", "Carson"])
    }

    func testDuplicateSessionIDsUseNewestStateOnly() {
        let now = date(2026, 7, 14, 12)
        let duplicates = [
            summary(
                date: now.addingTimeInterval(-600),
                project: "项目",
                tokens: 10,
                state: .running,
                updatedAt: now.addingTimeInterval(-10),
                sessionID: "same"
            ),
            summary(
                date: now.addingTimeInterval(-600),
                project: "项目",
                tokens: 20,
                state: .completed,
                updatedAt: now.addingTimeInterval(-5),
                sessionID: "same"
            )
        ]

        let snapshot = UsageAggregator.makeSnapshot(
            sessions: duplicates,
            now: now,
            calendar: utcCalendar
        )

        XCTAssertEqual(snapshot.sessions.count, 1)
        XCTAssertEqual(snapshot.sessions.first?.state, .completed)
        XCTAssertEqual(snapshot.sessions.first?.updatedAt, now.addingTimeInterval(-5))
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
        weeklyUsed: Double? = nil,
        weeklyLimitID: String? = nil,
        weeklyQuotaUpdatedAt: Date? = nil,
        sessionID: String = "session",
        agentNickname: String? = nil,
        isTopLevel: Bool = true
    ) -> SessionSummary {
        SessionSummary(
            date: date,
            projectName: project,
            sessionID: sessionID,
            agentNickname: agentNickname,
            isTopLevel: isTopLevel,
            totalTokens: tokens,
            longestTaskDuration: 0,
            state: state,
            updatedAt: updatedAt,
            weeklyUsedPercent: weeklyUsed,
            weeklyLimitID: weeklyLimitID,
            weeklyResetsAt: nil,
            weeklyQuotaUpdatedAt: weeklyQuotaUpdatedAt
        )
    }
}
