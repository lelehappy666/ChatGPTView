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
            "令牌仅存储在本机钥匙串"
        )
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
