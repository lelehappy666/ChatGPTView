import AppKit
import Foundation
import UserNotifications

enum NotificationAuthorizationState: Equatable {
    case notDetermined
    case denied
    case authorized
}

struct NotificationPermissionSnapshot: Equatable {
    let authorization: NotificationAuthorizationState
    let alertsEnabled: Bool
    let soundsEnabled: Bool
}

enum NotificationPermissionAction: Equatable {
    case none
    case requestAuthorization
    case promptForSettings
}

enum NotificationPermissionPolicy {
    static func action(
        for snapshot: NotificationPermissionSnapshot
    ) -> NotificationPermissionAction {
        switch snapshot.authorization {
        case .notDetermined:
            return .requestAuthorization
        case .denied:
            return .promptForSettings
        case .authorized:
            return snapshot.alertsEnabled && snapshot.soundsEnabled
                ? .none
                : .promptForSettings
        }
    }
}

struct CompletionNotificationMessage: Equatable {
    let title: String
    let body: String

    static func message(projectName: String, sessionName: String) -> Self {
        let sessionLabel = sessionName.hasSuffix("会话")
            ? sessionName
            : "\(sessionName) 会话"
        return Self(
            title: projectName,
            body: "\(sessionLabel)已完成"
        )
    }
}

@MainActor
final class ProjectCompletionNotifier: NSObject, UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    func ensureAuthorization() async {
        let settings = await center.notificationSettings()
        let action = NotificationPermissionPolicy.action(
            for: Self.snapshot(from: settings)
        )

        switch action {
        case .none:
            return
        case .requestAuthorization:
            let granted = (try? await center.requestAuthorization(
                options: [.alert, .sound]
            )) ?? false
            if !granted {
                showSettingsPrompt()
            }
        case .promptForSettings:
            showSettingsPrompt()
        }
    }

    func notify(projectName: String, sessionName: String) {
        let message = CompletionNotificationMessage.message(
            projectName: projectName,
            sessionName: sessionName
        )
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request, withCompletionHandler: nil)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    private static func snapshot(
        from settings: UNNotificationSettings
    ) -> NotificationPermissionSnapshot {
        let authorization: NotificationAuthorizationState
        switch settings.authorizationStatus {
        case .notDetermined:
            authorization = .notDetermined
        case .authorized, .provisional, .ephemeral:
            authorization = .authorized
        case .denied:
            authorization = .denied
        @unknown default:
            authorization = .denied
        }

        return NotificationPermissionSnapshot(
            authorization: authorization,
            alertsEnabled: settings.alertSetting == .enabled,
            soundsEnabled: settings.soundSetting == .enabled
        )
    }

    @MainActor
    private func showSettingsPrompt() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "需要开启通知权限"
        alert.informativeText = "Codex Monitor 需要通知权限，才能在项目完成时提醒你。请在系统设置中开启通知横幅和声音。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "打开通知设置")
        alert.addButton(withTitle: "稍后")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        openNotificationSettings()
    }

    @MainActor
    private func openNotificationSettings() {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.dafeng.codexmonitor"
        let values = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleIdentifier)",
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
        ]

        for value in values {
            guard let url = URL(string: value) else { continue }
            if NSWorkspace.shared.open(url) { return }
        }
    }
}
