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
        XCTAssertTrue(detector.completedSessions(in: [
            session("same", project: "项目", state: .completed, at: 102)
        ]).isEmpty)
    }

    func testCompletedSessionNotifiesWhileAnotherSessionInSameProjectRuns() {
        var detector = SessionCompletionDetector()
        let firstRunning = session("first", project: "Replaypoker", state: .running, at: 100)
        let secondRunning = session("second", project: "Replaypoker", state: .running, at: 100)

        XCTAssertTrue(detector.completedSessions(in: [firstRunning, secondRunning]).isEmpty)
        XCTAssertEqual(
            detector.completedSessions(in: [
                session("first", project: "Replaypoker", state: .completed, at: 101),
                secondRunning
            ]).map(\.id),
            ["first"]
        )
    }

    func testChildCompletionDoesNotNotifyWhileReplaypokerRootRuns() {
        var detector = SessionCompletionDetector()
        let rootRunning = session(
            "root",
            project: "Replaypoker(ios)",
            state: .running,
            at: 100,
            turnID: "root-turn"
        )
        let childRunning = session(
            "Epicurus",
            project: "Replaypoker(ios)",
            state: .running,
            at: 100,
            turnID: "child-turn",
            isTopLevel: false
        )

        XCTAssertTrue(detector.completedSessions(in: [rootRunning, childRunning]).isEmpty)
        XCTAssertTrue(detector.completedSessions(in: [
            session(
                "root",
                project: "Replaypoker(ios)",
                state: .running,
                at: 101,
                turnID: "root-turn"
            ),
            session(
                "Epicurus",
                project: "Replaypoker(ios)",
                state: .completed,
                at: 101,
                turnID: "child-turn",
                isTopLevel: false
            )
        ]).isEmpty)

        XCTAssertEqual(detector.completedSessions(in: [
            session(
                "root",
                project: "Replaypoker(ios)",
                state: .completed,
                at: 102,
                turnID: "root-turn"
            )
        ]).map(\.id), ["root"])
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

        XCTAssertTrue(detector.completedSessions(in: [
            session("a", project: "项目", state: .running, at: 100)
        ]).isEmpty)
        XCTAssertEqual(detector.completedSessions(in: [completed]).map(\.id), ["a"])
        XCTAssertTrue(detector.completedSessions(in: [completed]).isEmpty)
    }

    func testSameSessionCanNotifyAgainAtLaterCompletionTime() {
        var detector = SessionCompletionDetector()

        XCTAssertTrue(detector.completedSessions(in: [
            session("a", project: "项目", state: .running, at: 100, turnID: "turn-1")
        ]).isEmpty)
        XCTAssertEqual(
            detector.completedSessions(in: [
                session("a", project: "项目", state: .completed, at: 101, turnID: "turn-1")
            ]).map(\.id),
            ["a"]
        )
        XCTAssertTrue(detector.completedSessions(in: [
            session("a", project: "项目", state: .running, at: 102, turnID: "turn-2")
        ]).isEmpty)
        XCTAssertEqual(
            detector.completedSessions(in: [
                session("a", project: "项目", state: .completed, at: 103, turnID: "turn-2")
            ]).map(\.id),
            ["a"]
        )
    }

    func testFastCompletedTurnNotifiesEvenWhenRunningSnapshotWasMissed() {
        var detector = SessionCompletionDetector()

        XCTAssertTrue(detector.completedSessions(in: [
            session("a", project: "项目", state: .running, at: 100, turnID: "turn-a")
        ]).isEmpty)
        XCTAssertEqual(detector.completedSessions(in: [
            session("a", project: "项目", state: .completed, at: 101, turnID: "turn-b")
        ]).map(\.turnID), ["turn-b"])
    }

    func testMissingTurnIDNeverTriggersCompletionNotification() {
        var detector = SessionCompletionDetector()

        XCTAssertTrue(detector.completedSessions(in: [
            session("a", project: "项目", state: .running, at: 100, turnID: nil)
        ]).isEmpty)
        XCTAssertTrue(detector.completedSessions(in: [
            session("a", project: "项目", state: .completed, at: 101, turnID: nil)
        ]).isEmpty)
    }

    func testCompletionConfirmationRejectsSessionThatAlreadyStartedNextTurn() {
        let completed = session(
            "a",
            project: "项目",
            state: .completed,
            at: 101,
            turnID: "turn-a"
        )
        let nextRunning = session(
            "a",
            project: "项目",
            state: .running,
            at: 102,
            turnID: "turn-b"
        )

        XCTAssertFalse(CompletionConfirmation.matches(
            candidate: completed,
            latest: nextRunning,
            now: Date(timeIntervalSince1970: 103),
            freshness: 15
        ))
    }

    func testCompletionConfirmationAcceptsUnchangedCompletedTurn() {
        let completed = session(
            "a",
            project: "项目",
            state: .completed,
            at: 101,
            turnID: "turn-a"
        )

        XCTAssertTrue(CompletionConfirmation.matches(
            candidate: completed,
            latest: completed,
            now: Date(timeIntervalSince1970: 103),
            freshness: 15
        ))
    }

    func testCompletionConfirmationRejectsFutureCompletionTimestamp() {
        let completed = session(
            "a",
            project: "项目",
            state: .completed,
            at: 110,
            turnID: "turn-a"
        )

        XCTAssertFalse(CompletionConfirmation.matches(
            candidate: completed,
            latest: completed,
            now: Date(timeIntervalSince1970: 109),
            freshness: 15
        ))
    }

    func testCompletionConfirmationRejectsInternalSession() {
        let child = session(
            "Epicurus",
            project: "Replaypoker(ios)",
            state: .completed,
            at: 101,
            turnID: "child-turn",
            isTopLevel: false
        )

        XCTAssertFalse(CompletionConfirmation.matches(
            candidate: child,
            latest: child,
            now: Date(timeIntervalSince1970: 103),
            freshness: 15
        ))
    }

    func testPendingPolicyCancelsSameTurnWhenSessionReturnsToRunning() {
        let pendingKeys = ["same::turn-a", "other::turn-b"]
        let latest = session(
            "same",
            project: "项目",
            state: .running,
            at: 102,
            turnID: "turn-a"
        )

        XCTAssertEqual(
            CompletionPendingPolicy.keysToCancel(
                pendingKeys: pendingKeys,
                latest: latest
            ),
            ["same::turn-a"]
        )
    }

    func testPendingPolicyCancelsOldTurnButKeepsOtherSession() {
        let pendingKeys = ["same::turn-a", "other::turn-b"]
        let latest = session(
            "same",
            project: "项目",
            state: .completed,
            at: 103,
            turnID: "turn-new"
        )

        XCTAssertEqual(
            CompletionPendingPolicy.keysToCancel(
                pendingKeys: pendingKeys,
                latest: latest
            ),
            ["same::turn-a"]
        )
    }

    func testPendingPolicyCancelsCandidateWhenLatestIdentityIsInternal() {
        let latest = session(
            "same",
            project: "项目",
            state: .completed,
            at: 103,
            turnID: "turn-a",
            isTopLevel: false
        )

        XCTAssertEqual(
            CompletionPendingPolicy.keysToCancel(
                pendingKeys: ["same::turn-a", "other::turn-b"],
                latest: latest
            ),
            ["same::turn-a"]
        )
    }

    private func session(
        _ id: String,
        project: String,
        state: ProjectRunState,
        at timestamp: TimeInterval,
        turnID: String? = "turn",
        isTopLevel: Bool = true
    ) -> SessionActivity {
        SessionActivity(
            id: id,
            projectName: project,
            displayName: id,
            state: state,
            updatedAt: Date(timeIntervalSince1970: timestamp),
            turnID: turnID,
            isTopLevel: isTopLevel
        )
    }
}
