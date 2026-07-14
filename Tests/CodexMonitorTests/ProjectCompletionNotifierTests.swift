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

    func testCompletionNotificationUsesExpectedChineseCopy() {
        XCTAssertEqual(
            CompletionNotificationMessage.message(for: "Codex额度"),
            CompletionNotificationMessage(
                title: "Codex 项目已完成",
                body: "Codex额度 已完成"
            )
        )
    }
}
