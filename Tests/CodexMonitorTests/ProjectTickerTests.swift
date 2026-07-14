import XCTest
@testable import CodexMonitor

@MainActor
final class ProjectTickerTests: XCTestCase {
    func testEmptyTickerHasNoCurrentProject() {
        let ticker = ProjectTickerState()

        ticker.advance()

        XCTAssertNil(ticker.currentProject)
        XCTAssertEqual(ticker.index, 0)
    }

    func testTickerWrapsAfterLastProject() {
        let ticker = ProjectTickerState()
        ticker.projects = [project("One"), project("Two")]

        ticker.advance()
        XCTAssertEqual(ticker.currentProject?.name, "Two")
        ticker.advance()
        XCTAssertEqual(ticker.currentProject?.name, "One")
    }

    func testPausedTickerDoesNotAdvance() {
        let ticker = ProjectTickerState()
        ticker.projects = [project("One"), project("Two")]
        ticker.isPaused = true

        ticker.advance()

        XCTAssertEqual(ticker.currentProject?.name, "One")
    }

    private func project(_ name: String) -> ProjectActivity {
        ProjectActivity(name: name, state: .running, updatedAt: .now)
    }
}
