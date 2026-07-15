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
                cancelSupersededCompletions(using: snapshot.sessions)
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
        let age = Date.now.timeIntervalSince(session.updatedAt)
        guard session.isTopLevel,
              let turnID = session.turnID,
              age >= 0,
              age <= notificationFreshness else {
            return
        }

        let completionKey = "\(session.id)::\(turnID)"
        pendingCompletionTasks[completionKey]?.cancel()
        pendingCompletionUpdates[completionKey] = session.updatedAt
        pendingCompletionTasks[completionKey] = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }

            store?.requestRefresh()
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled,
                  pendingCompletionUpdates[completionKey] == session.updatedAt,
                  let latest = store?.snapshot.sessions.first(where: { $0.id == session.id }),
                  CompletionConfirmation.matches(
                    candidate: session,
                    latest: latest,
                    now: .now,
                    freshness: notificationFreshness
                  ) else {
                clearPendingCompletion(key: completionKey, update: session.updatedAt)
                return
            }

            completionNotifier.notify(
                projectName: session.projectName,
                sessionName: session.displayName
            )
            clearPendingCompletion(key: completionKey, update: session.updatedAt)
        }
    }

    private func cancelSupersededCompletions(using sessions: [SessionActivity]) {
        for latest in sessions {
            let obsoleteKeys = CompletionPendingPolicy.keysToCancel(
                pendingKeys: Array(pendingCompletionTasks.keys),
                latest: latest
            )
            for key in obsoleteKeys {
                pendingCompletionTasks[key]?.cancel()
                pendingCompletionTasks.removeValue(forKey: key)
                pendingCompletionUpdates.removeValue(forKey: key)
            }
        }
    }

    private func clearPendingCompletion(key: String, update: Date) {
        guard pendingCompletionUpdates[key] == update else { return }
        pendingCompletionUpdates.removeValue(forKey: key)
        pendingCompletionTasks.removeValue(forKey: key)
    }
}
