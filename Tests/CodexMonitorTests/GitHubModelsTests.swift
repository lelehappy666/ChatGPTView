import XCTest
@testable import CodexMonitor

final class GitHubModelsTests: XCTestCase {
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
