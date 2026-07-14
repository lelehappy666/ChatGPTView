import XCTest
@testable import CodexMonitor

final class ProjectVisibilityTests: XCTestCase {
    func testAllStatesExpireAtSixtySeconds() {
        let now = Date(timeIntervalSince1970: 1_000)
        let projects = [
            project("运行", .running, now.addingTimeInterval(-60)),
            project("完成", .completed, now.addingTimeInterval(-60)),
            project("报错", .failed, now.addingTimeInterval(-60))
        ]

        XCTAssertTrue(projects.visibleForMenu(at: now).isEmpty)
    }

    func testAllStatesRemainVisibleBeforeSixtySeconds() {
        let now = Date(timeIntervalSince1970: 1_000)
        let projects = [
            project("运行", .running, now.addingTimeInterval(-59.9)),
            project("完成", .completed, now.addingTimeInterval(-59.9)),
            project("报错", .failed, now.addingTimeInterval(-59.9))
        ]

        XCTAssertEqual(projects.visibleForMenu(at: now).count, 3)
    }

    private func project(
        _ name: String,
        _ state: ProjectRunState,
        _ updatedAt: Date
    ) -> ProjectActivity {
        ProjectActivity(name: name, state: state, updatedAt: updatedAt)
    }
}
