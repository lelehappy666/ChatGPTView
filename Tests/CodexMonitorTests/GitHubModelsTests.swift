import XCTest
@testable import CodexMonitor

final class GitHubModelsTests: XCTestCase {
    func testAuthorizationCopyMatchesApprovedChineseDesign() {
        XCTAssertEqual(GitHubAuthorizationContent.title, "连接 GitHub")
        XCTAssertEqual(
            GitHubAuthorizationContent.message,
            "授权后查看贡献记录和最近更新的仓库"
        )
        XCTAssertEqual(GitHubAuthorizationContent.primaryAction, "授权 GitHub")
        XCTAssertEqual(
            GitHubAuthorizationContent.privacyNote,
            "仅请求读取公开仓库与活动数据"
        )
    }

    func testAuthorizationUsesOneButtonAndBindsRecognizedClipboardToken() {
        XCTAssertEqual(
            GitHubAuthorizationAction.next(clipboard: "github_pat_example"),
            .bind(token: "github_pat_example")
        )
        XCTAssertEqual(
            GitHubAuthorizationAction.next(clipboard: "ghp_example"),
            .bind(token: "ghp_example")
        )
        XCTAssertEqual(
            GitHubAuthorizationAction.next(clipboard: "普通文本"),
            .openTokenPage
        )
    }

    func testCanvasRenderPlanCreatesSevenRowsWithoutViewPerCellLayout() {
        let days = (0..<14).map {
            GitHubContributionDay(
                date: Date(timeIntervalSince1970: Double($0) * 86_400),
                contributionCount: $0
            )
        }

        let cells = GitHubContributionRenderPlan.cells(
            days: days,
            width: 15,
            height: 55,
            spacing: 1
        )

        XCTAssertEqual(cells.count, 14)
        XCTAssertEqual(cells[0].rect, CGRect(x: 0, y: 0, width: 7, height: 7))
        XCTAssertEqual(cells[6].rect, CGRect(x: 0, y: 48, width: 7, height: 7))
        XCTAssertEqual(cells[7].rect, CGRect(x: 8, y: 0, width: 7, height: 7))
        XCTAssertEqual(cells[13].rect, CGRect(x: 8, y: 48, width: 7, height: 7))
    }

    func testCanvasRenderPlanKeepsSevenRowsWithinAvailableHeight() {
        let availableHeight: CGFloat = 72
        let days = (0..<371).map {
            GitHubContributionDay(
                date: Date(timeIntervalSince1970: Double($0) * 86_400),
                contributionCount: $0
            )
        }

        let cells = GitHubContributionRenderPlan.cells(
            days: days,
            width: 600,
            height: availableHeight,
            spacing: 1.25
        )

        let expectedCellSize = (availableHeight - 6 * 1.25) / 7
        XCTAssertEqual(cells[0].rect.width, expectedCellSize, accuracy: 0.001)
        XCTAssertEqual(cells[0].rect.height, expectedCellSize, accuracy: 0.001)
        XCTAssertTrue(cells.allSatisfy { $0.rect.maxY <= availableHeight })
    }

    func testContributionScaleUsesFiveStableLevels() {
        XCTAssertEqual(GitHubContributionScale.level(count: 0), 0)
        XCTAssertEqual(GitHubContributionScale.level(count: 1), 1)
        XCTAssertEqual(GitHubContributionScale.level(count: 3), 1)
        XCTAssertEqual(GitHubContributionScale.level(count: 4), 2)
        XCTAssertEqual(GitHubContributionScale.level(count: 9), 2)
        XCTAssertEqual(GitHubContributionScale.level(count: 10), 3)
        XCTAssertEqual(GitHubContributionScale.level(count: 19), 3)
        XCTAssertEqual(GitHubContributionScale.level(count: 20), 4)
        XCTAssertEqual(GitHubContributionScale.level(count: 30), 4)
        XCTAssertEqual(GitHubContributionScale.level(count: 80), 4)
    }

    func testRepositoryURLPolicyOnlyAllowsGitHubHTTPSLinks() {
        XCTAssertTrue(
            GitHubRepositoryLinkPolicy.canOpen(
                URL(string: "https://github.com/lele/project")!
            )
        )
        XCTAssertFalse(
            GitHubRepositoryLinkPolicy.canOpen(
                URL(string: "http://github.com/lele/project")!
            )
        )
        XCTAssertFalse(
            GitHubRepositoryLinkPolicy.canOpen(
                URL(string: "https://example.com/lele/project")!
            )
        )
    }

    func testRepositoriesAreSortedByLatestPushAndLimitedToSix() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let repositories = (0..<8).map { index in
            GitHubRepository(
                name: "repo-\(index)",
                url: URL(string: "https://github.com/test/repo-\(index)")!,
                pushedAt: base.addingTimeInterval(Double(index) * 60)
            )
        }

        XCTAssertEqual(
            repositories.recentlyPushed(limit: 6).map(\.name),
            ["repo-7", "repo-6", "repo-5", "repo-4", "repo-3", "repo-2"]
        )
    }

    func testRepositoryLimitNeverReturnsNegativeCount() {
        let repository = GitHubRepository(
            name: "repo",
            url: URL(string: "https://github.com/test/repo")!,
            pushedAt: .now
        )

        XCTAssertTrue([repository].recentlyPushed(limit: -1).isEmpty)
    }

    func testReferenceRepositoryGridUsesTwoColumnsAndThreeRows() {
        let metrics = RepositoryGridMetrics.make(density: .reference)

        XCTAssertEqual(metrics.columnCount, 2)
        XCTAssertEqual(metrics.rowCount, 3)
        XCTAssertGreaterThan(
            metrics.rowHeight,
            RepositoryGridMetrics.make(density: .compact).rowHeight
        )
    }

    func testGitHubMonthLabelsFollowContributionDates() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let days = [
            GitHubContributionDay(
                date: calendar.date(
                    from: DateComponents(year: 2026, month: 5, day: 1)
                )!,
                contributionCount: 0
            ),
            GitHubContributionDay(
                date: calendar.date(
                    from: DateComponents(year: 2026, month: 6, day: 1)
                )!,
                contributionCount: 0
            ),
            GitHubContributionDay(
                date: calendar.date(
                    from: DateComponents(year: 2026, month: 7, day: 1)
                )!,
                contributionCount: 0
            )
        ]

        XCTAssertEqual(
            MenuGitHubMonthLabelPlan.titles(
                days: days,
                calendar: calendar
            ),
            ["5月", "6月", "7月"]
        )
    }

    func testReferenceRepositoryRowsUseGitHubMark() {
        XCTAssertEqual(
            RepositoryLeadingIcon.make(density: .reference),
            .github
        )
        XCTAssertEqual(
            RepositoryLeadingIcon.make(density: .compact),
            .repository
        )
        XCTAssertEqual(
            RepositoryLeadingIcon.make(density: .standard),
            .repository
        )
    }
}
