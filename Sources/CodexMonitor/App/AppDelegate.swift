import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: MonitorStore?
    private var watcher: SessionDirectoryWatcher?
    private var menuBarController: MenuBarController?
    private var notchWindowController: NotchWindowController?
    private let completionNotifier = ProjectCompletionNotifier()
    private var completionDetector = SessionCompletionDetector()
    private var snapshotCancellable: AnyCancellable?
    private var pendingCompletionTasks: [String: Task<Void, Never>] = [:]
    private var pendingCompletionUpdates: [String: Date] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let sessionsRoot = AppPaths.sessionsRoot()
        let store = MonitorStore(root: sessionsRoot)
        self.store = store

        Task { [completionNotifier] in
            await completionNotifier.ensureAuthorization()
        }
        snapshotCancellable = store.$snapshot
            .dropFirst()
            .sink { [weak self] snapshot in
                guard let self else { return }
                for session in completionDetector.completedSessions(in: snapshot.sessions) {
                    scheduleCompletionNotification(for: session)
                }
            }

        let watcher = SessionDirectoryWatcher(root: sessionsRoot) { [weak store] in
            Task { @MainActor in
                store?.requestRefresh()
            }
        }
        watcher.start()
        self.watcher = watcher

        let menuBarController = MenuBarController(store: store)
        menuBarController.start()
        self.menuBarController = menuBarController

        let notchWindowController = NotchWindowController(store: store)
        notchWindowController.start()
        self.notchWindowController = notchWindowController

        store.requestRefresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        pendingCompletionTasks.values.forEach { $0.cancel() }
        watcher?.stop()
        notchWindowController?.stop()
    }

    private func scheduleCompletionNotification(for session: SessionActivity) {
        let notificationFreshness: TimeInterval = 15
        guard Date.now.timeIntervalSince(session.updatedAt) <= notificationFreshness else {
            return
        }

        pendingCompletionTasks[session.id]?.cancel()
        pendingCompletionUpdates[session.id] = session.updatedAt
        pendingCompletionTasks[session.id] = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }

            store?.requestRefresh()
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled,
                  pendingCompletionUpdates[session.id] == session.updatedAt,
                  let latest = store?.snapshot.sessions.first(where: { $0.id == session.id }),
                  latest.state == .completed,
                  latest.updatedAt == session.updatedAt,
                  Date.now.timeIntervalSince(latest.updatedAt) <= notificationFreshness else {
                clearPendingCompletion(id: session.id, update: session.updatedAt)
                return
            }

            completionNotifier.notify(
                projectName: session.projectName,
                sessionName: session.displayName
            )
            clearPendingCompletion(id: session.id, update: session.updatedAt)
        }
    }

    private func clearPendingCompletion(id: String, update: Date) {
        guard pendingCompletionUpdates[id] == update else { return }
        pendingCompletionUpdates.removeValue(forKey: id)
        pendingCompletionTasks.removeValue(forKey: id)
    }
}
