import XCTest
@testable import CodexMonitor

final class ProjectCompletionDetectorTests: XCTestCase {
    func testOnlyRunningToCompletedProducesNotification() {
        var detector = ProjectCompletionDetector()

        XCTAssertTrue(detector.completedProjects(in: [project("甲", .running)]).isEmpty)
        XCTAssertEqual(
            detector.completedProjects(in: [project("甲", .completed)]).map(\.name),
            ["甲"]
        )
        XCTAssertTrue(detector.completedProjects(in: [project("甲", .completed)]).isEmpty)
    }

    func testInitialCompletedAndFailedProjectsDoNotProduceNotification() {
        var detector = ProjectCompletionDetector()

        XCTAssertTrue(detector.completedProjects(in: [
            project("历史完成", .completed),
            project("报错", .failed)
        ]).isEmpty)
    }

    func testProjectCanNotifyAgainAfterReturningToRunning() {
        var detector = ProjectCompletionDetector()

        _ = detector.completedProjects(in: [project("甲", .running)])
        XCTAssertEqual(
            detector.completedProjects(in: [project("甲", .completed)]).map(\.name),
            ["甲"]
        )
        XCTAssertTrue(detector.completedProjects(in: [project("甲", .running)]).isEmpty)
        XCTAssertEqual(
            detector.completedProjects(in: [project("甲", .completed)]).map(\.name),
            ["甲"]
        )
    }

    private func project(_ name: String, _ state: ProjectRunState) -> ProjectActivity {
        ProjectActivity(name: name, state: state, updatedAt: .now)
    }
}
