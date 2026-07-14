import Foundation
import UserNotifications

struct CompletionNotificationMessage: Equatable {
    let title: String
    let body: String

    static func message(for projectName: String) -> Self {
        Self(
            title: "Codex 项目已完成",
            body: "\(projectName) 已完成"
        )
    }
}

final class ProjectCompletionNotifier: NSObject, UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notify(projectName: String) {
        let message = CompletionNotificationMessage.message(for: projectName)
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

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
