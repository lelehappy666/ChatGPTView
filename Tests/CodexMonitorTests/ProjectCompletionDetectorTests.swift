import XCTest
@testable import CodexMonitor

final class ProjectCompletionDetectorTests: XCTestCase {
    func testFirstRealSnapshotOnlyEstablishesSessionBaseline() {
        var detector = SessionCompletionDetector()

        XCTAssertTrue(detector.completedSessions(in: [
            session("history", project: "历史项目", state: .completed, at: 100),
            session("failed", project: "报错项目", state: .failed, at: 100)
        ]).isEmpty)
    }

    func testDuplicateSessionIDsInBaselineAreSafelyMerged() {
        var detector = SessionCompletionDetector()

        XCTAssertTrue(detector.completedSessions(in: [
            session("same", project: "项目", state: .completed, at: 100),
            session("same", project: "项目", state: .completed, at: 101)
        ]).isEmpty)
        XCTAssertEqual(
            detector.completedSessions(in: [
                session("same", project: "项目", state: .completed, at: 102)
            ]).map(\.id),
            ["same"]
        )
    }

    func testCompletedSessionNotifiesWhileAnotherSessionInSameProjectRuns() {
        var detector = SessionCompletionDetector()
        let running = session("running", project: "Replaypoker", state: .running, at: 100)

        XCTAssertTrue(detector.completedSessions(in: [running]).isEmpty)
        XCTAssertEqual(
            detector.completedSessions(in: [
                running,
                session("completed", project: "Replaypoker", state: .completed, at: 101)
            ]).map(\.id),
            ["completed"]
        )
    }

    func testDifferentCompletedSessionsNotifyIndependently() {
        var detector = SessionCompletionDetector()

        XCTAssertTrue(detector.completedSessions(in: []).isEmpty)
        XCTAssertEqual(
            detector.completedSessions(in: [
                session("a", project: "同一项目", state: .completed, at: 101),
                session("b", project: "同一项目", state: .completed, at: 102)
            ]).map(\.id),
            ["a", "b"]
        )
    }

    func testSameSessionCompletionTimestampOnlyNotifiesOnce() {
        var detector = SessionCompletionDetector()
        let completed = session("a", project: "项目", state: .completed, at: 101)

        XCTAssertTrue(detector.completedSessions(in: []).isEmpty)
        XCTAssertEqual(detector.completedSessions(in: [completed]).map(\.id), ["a"])
        XCTAssertTrue(detector.completedSessions(in: [completed]).isEmpty)
    }

    func testSameSessionCanNotifyAgainAtLaterCompletionTime() {
        var detector = SessionCompletionDetector()

        XCTAssertTrue(detector.completedSessions(in: []).isEmpty)
        XCTAssertEqual(
            detector.completedSessions(in: [
                session("a", project: "项目", state: .completed, at: 101)
            ]).map(\.id),
            ["a"]
        )
        XCTAssertTrue(detector.completedSessions(in: [
            session("a", project: "项目", state: .running, at: 102)
        ]).isEmpty)
        XCTAssertEqual(
            detector.completedSessions(in: [
                session("a", project: "项目", state: .completed, at: 103)
            ]).map(\.id),
            ["a"]
        )
    }

    private func session(
        _ id: String,
        project: String,
        state: ProjectRunState,
        at timestamp: TimeInterval
    ) -> SessionActivity {
        SessionActivity(
            id: id,
            projectName: project,
            displayName: id,
            state: state,
            updatedAt: Date(timeIntervalSince1970: timestamp)
        )
    }
}
