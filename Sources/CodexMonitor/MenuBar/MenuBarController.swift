import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let store: MonitorStore
    private let statusItem = NSStatusBar.system.statusItem(withLength: 300)
    private var hostingView: NSHostingView<MenuBarContentView>?

    init(store: MonitorStore) {
        self.store = store
        super.init()
    }

    func start() {
        guard let button = statusItem.button else { return }
        let hostingView = NSHostingView(rootView: MenuBarContentView(store: store))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        button.image = nil
        button.title = ""
        button.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: button.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        self.hostingView = hostingView

        let menu = NSMenu()
        menu.addItem(withTitle: "刷新数据", action: #selector(refresh), keyEquivalent: "r").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 Codex Monitor", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
    }

    @objc private func refresh() {
        store.requestRefresh()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
