import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: MonitorStore?
    private var watcher: SessionDirectoryWatcher?
    private var menuBarController: MenuBarController?
    private var notchWindowController: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let sessionsRoot = AppPaths.sessionsRoot()
        let store = MonitorStore(root: sessionsRoot)
        self.store = store

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
        watcher?.stop()
        notchWindowController?.stop()
    }
}
