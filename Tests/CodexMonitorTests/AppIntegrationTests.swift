import XCTest
@testable import CodexMonitor

final class AppIntegrationTests: XCTestCase {
    func testSessionsRootUsesCodexDirectoryInsideHome() {
        let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)

        XCTAssertEqual(
            AppPaths.sessionsRoot(home: home).path,
            "/Users/tester/.codex/sessions"
        )
    }

    func testPageNavigationClampsToThreePages() {
        XCTAssertEqual(PageNavigation.target(from: 0, delta: 30), 0)
        XCTAssertEqual(PageNavigation.target(from: 0, delta: -30), 1)
        XCTAssertEqual(PageNavigation.target(from: 2, delta: -30), 2)
        XCTAssertEqual(PageNavigation.target(from: 2, delta: 30), 1)
    }
}
