import XCTest
@testable import CodexMonitor

final class ProjectCompletionNotifierTests: XCTestCase {
    func testUndeterminedPermissionRequestsAuthorization() {
        XCTAssertEqual(
            NotificationPermissionPolicy.action(for: .init(
                authorization: .notDetermined,
                alertsEnabled: false,
                soundsEnabled: false
            )),
            .requestAuthorization
        )
    }

    func testCompletePermissionNeedsNoAction() {
        XCTAssertEqual(
            NotificationPermissionPolicy.action(for: .init(
                authorization: .authorized,
                alertsEnabled: true,
                soundsEnabled: true
            )),
            .none
        )
    }

    func testIncompletePermissionPromptsForSettings() {
        let snapshots = [
            NotificationPermissionSnapshot(
                authorization: .denied,
                alertsEnabled: false,
                soundsEnabled: false
            ),
            NotificationPermissionSnapshot(
                authorization: .authorized,
                alertsEnabled: false,
                soundsEnabled: true
            ),
            NotificationPermissionSnapshot(
                authorization: .authorized,
                alertsEnabled: true,
                soundsEnabled: false
            )
        ]

        XCTAssertEqual(
            snapshots.map(NotificationPermissionPolicy.action(for:)),
            [.promptForSettings, .promptForSettings, .promptForSettings]
        )
    }

    func testCompletionNotificationUsesProjectNameAsTitle() {
        XCTAssertEqual(
            CompletionNotificationMessage.message(
                projectName: "Replaypoker(ios)",
                sessionName: "Carson"
            ),
            CompletionNotificationMessage(
                title: "Replaypoker(ios)",
                body: "Carson 会话已完成"
            )
        )
    }

    func testCompletionNotificationSupportsTimeBasedSessionName() {
        XCTAssertEqual(
            CompletionNotificationMessage.message(
                projectName: "Codex额度",
                sessionName: "14:36 会话"
            ),
            CompletionNotificationMessage(
                title: "Codex额度",
                body: "14:36 会话已完成"
            )
        )
    }
}
