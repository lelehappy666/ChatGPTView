import XCTest
@testable import CodexMonitor

final class ProjectCompletionDetectorTests: XCTestCase {
    func testFirstRealSnapshotOnlyEstablishesBaseline() {
        var detector = ProjectCompletionDetector()

        XCTAssertTrue(detector.completedProjects(in: [
            project("历史完成", .completed, at: 100),
            project("历史报错", .failed, at: 100)
        ]).isEmpty)
    }

    func testFastCompletionAfterEmptyBaselineProducesNotification() {
        var detector = ProjectCompletionDetector()

        XCTAssertTrue(detector.completedProjects(in: []).isEmpty)
        XCTAssertEqual(
            detector.completedProjects(in: [project("快速任务", .completed, at: 101)]).map(\.name),
            ["快速任务"]
        )
    }

    func testSameCompletionTimestampOnlyProducesOneNotification() {
        var detector = ProjectCompletionDetector()

        XCTAssertTrue(detector.completedProjects(in: []).isEmpty)
        XCTAssertEqual(
            detector.completedProjects(in: [project("甲", .completed, at: 101)]).map(\.name),
            ["甲"]
        )
        XCTAssertTrue(
            detector.completedProjects(in: [project("甲", .completed, at: 101)]).isEmpty
        )
    }

    func testLaterCompletionTimestampCanNotifyAgain() {
        var detector = ProjectCompletionDetector()

        XCTAssertTrue(detector.completedProjects(in: [project("甲", .running, at: 100)]).isEmpty)
        XCTAssertEqual(
            detector.completedProjects(in: [project("甲", .completed, at: 101)]).map(\.name),
            ["甲"]
        )
        XCTAssertTrue(detector.completedProjects(in: [project("甲", .running, at: 102)]).isEmpty)
        XCTAssertEqual(
            detector.completedProjects(in: [project("甲", .completed, at: 103)]).map(\.name),
            ["甲"]
        )
    }

    private func project(
        _ name: String,
        _ state: ProjectRunState,
        at timestamp: TimeInterval
    ) -> ProjectActivity {
        ProjectActivity(
            name: name,
            state: state,
            updatedAt: Date(timeIntervalSince1970: timestamp)
        )
    }
}
