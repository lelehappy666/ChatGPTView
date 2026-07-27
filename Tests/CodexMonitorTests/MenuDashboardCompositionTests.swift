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

    func testReferenceDashboardUsesOneFullWidthColumn() {
        XCTAssertEqual(MenuDashboardComposition.sections.count, 5)
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

    func testWeeklyQuotaPresentationShowsFreshQuota() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let presentation = MenuWeeklyQuotaPresentation.make(
            quota: WeeklyQuota(
                remainingPercent: 34,
                resetsAt: now.addingTimeInterval(2 * 86_400 + 3 * 3_600),
                updatedAt: now.addingTimeInterval(-60)
            ),
            now: now
        )

        XCTAssertEqual(presentation.remainingText, "34")
        XCTAssertTrue(presentation.showsRemainingUnit)
        XCTAssertEqual(presentation.usedText, "66%")
        XCTAssertEqual(presentation.usedFraction, 0.66)
        XCTAssertEqual(presentation.resetText, "2 天 3 小时")
        XCTAssertTrue(presentation.isFresh)
    }

    func testWeeklyQuotaPresentationKeepsLastKnownQuotaWithoutClaimingFreshness() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let presentation = MenuWeeklyQuotaPresentation.make(
            quota: WeeklyQuota(
                remainingPercent: 77,
                resetsAt: now.addingTimeInterval(2 * 86_400),
                updatedAt: now.addingTimeInterval(
                    -QuotaFreshnessPolicy.freshDuration - 1
                )
            ),
            now: now
        )

        XCTAssertEqual(presentation.remainingText, "77")
        XCTAssertTrue(presentation.showsRemainingUnit)
        XCTAssertEqual(presentation.usedText, "23%")
        XCTAssertEqual(presentation.usedFraction, 0.23)
        XCTAssertEqual(presentation.resetText, "2 天 0 小时")
        XCTAssertFalse(presentation.isFresh)
    }

    func testWeeklyQuotaPresentationHidesMissingQuotaAndResetCountdown() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let presentation = MenuWeeklyQuotaPresentation.make(
            quota: WeeklyQuota(
                remainingPercent: nil,
                resetsAt: now.addingTimeInterval(2 * 86_400),
                updatedAt: now
            ),
            now: now
        )

        XCTAssertEqual(presentation.remainingText, "—")
        XCTAssertFalse(presentation.showsRemainingUnit)
        XCTAssertEqual(presentation.usedText, "—")
        XCTAssertNil(presentation.usedFraction)
        XCTAssertEqual(presentation.resetText, "—")
        XCTAssertFalse(presentation.isFresh)
    }

    func testLocalUsagePresentationShowsEmptyStateWithoutScannedData() {
        XCTAssertEqual(
            MenuLocalUsagePresentation.make(snapshot: .empty),
            .empty
        )
    }

    func testLocalUsagePresentationKeepsMetricsForRealZeroUsage() {
        let snapshot = MonitorSnapshot(
            weeklyQuota: WeeklyQuota(remainingPercent: nil, resetsAt: nil),
            dailyActivity: [],
            lifetimeTokens: 0,
            peakTokens: 0,
            longestTaskDuration: 0,
            currentStreakDays: 0,
            longestStreakDays: 0,
            projects: [],
            sessions: [],
            lastUpdatedAt: Date(timeIntervalSince1970: 1_000_000)
        )

        XCTAssertEqual(
            MenuLocalUsagePresentation.make(snapshot: snapshot),
            .metrics
        )
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

    func testCompactRepositoryGridFitsThreeRowsInsideEightyPoints() {
        let metrics = RepositoryGridMetrics.make(density: .compact)

        XCTAssertEqual(metrics.rowCount, 3)
        XCTAssertLessThanOrEqual(metrics.totalHeight, 80)
        XCTAssertLessThan(
            metrics.rowHeight,
            RepositoryGridMetrics.make(density: .standard).rowHeight
        )
    }

    func testGitHubMenuPresentationMapsUnboundStateToAuthorization() {
        XCTAssertEqual(
            GitHubMenuPresentation.make(state: .unbound(message: nil)),
            .authorization(message: nil)
        )
    }

    func testGitHubMenuPresentationShowsCachedContentWhileLoading() {
        let snapshot = makeGitHubSnapshot()

        XCTAssertEqual(
            GitHubMenuPresentation.make(state: .loading(cached: snapshot)),
            .content(snapshot: snapshot, statusMessage: "正在刷新")
        )
    }

    func testGitHubMenuPresentationShowsLoadedContentWithoutStatusMessage() {
        let snapshot = makeGitHubSnapshot()

        XCTAssertEqual(
            GitHubMenuPresentation.make(state: .loaded(snapshot)),
            .content(snapshot: snapshot, statusMessage: nil)
        )
    }

    func testGitHubMenuPresentationRetainsCachedContentAfterRefreshFailure() {
        let snapshot = makeGitHubSnapshot()

        XCTAssertEqual(
            GitHubMenuPresentation.make(
                state: .failed(message: "网络错误", cached: snapshot)
            ),
            .content(snapshot: snapshot, statusMessage: "网络错误")
        )
    }

    func testPopoverAutoCloseStartsOnlyAfterPointerEntered() {
        var state = MenuPopoverHoverState()

        XCTAssertEqual(state.update(isInside: false), .none)
        XCTAssertEqual(state.update(isInside: true), .cancelClose)
        XCTAssertEqual(state.update(isInside: false), .scheduleClose)
        XCTAssertEqual(state.update(isInside: true), .cancelClose)
    }

    func testPopoverAutoCloseResetStartsANewOpeningCycle() {
        var state = MenuPopoverHoverState()
        _ = state.update(isInside: true)
        _ = state.update(isInside: false)

        state.reset()

        XCTAssertEqual(state.update(isInside: false), .none)
    }

    private func makeGitHubSnapshot() -> GitHubActivitySnapshot {
        GitHubActivitySnapshot(
            username: "octocat",
            totalContributions: 42,
            contributionDays: [],
            repositories: [],
            fetchedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
