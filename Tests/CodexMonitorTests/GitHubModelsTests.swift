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
            spacing: 1
        )

        XCTAssertEqual(cells.count, 14)
        XCTAssertEqual(cells[0].rect, CGRect(x: 0, y: 0, width: 7, height: 7))
        XCTAssertEqual(cells[6].rect, CGRect(x: 0, y: 48, width: 7, height: 7))
        XCTAssertEqual(cells[7].rect, CGRect(x: 8, y: 0, width: 7, height: 7))
        XCTAssertEqual(cells[13].rect, CGRect(x: 8, y: 48, width: 7, height: 7))
    }

    func testContributionScaleUsesFiveStableLevels() {
        XCTAssertEqual(GitHubContributionScale.level(count: 0, maximum: 20), 0)
        XCTAssertEqual(GitHubContributionScale.level(count: 1, maximum: 20), 1)
        XCTAssertEqual(GitHubContributionScale.level(count: 5, maximum: 20), 1)
        XCTAssertEqual(GitHubContributionScale.level(count: 10, maximum: 20), 2)
        XCTAssertEqual(GitHubContributionScale.level(count: 15, maximum: 20), 3)
        XCTAssertEqual(GitHubContributionScale.level(count: 20, maximum: 20), 4)
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
}
