import AppKit
import Combine
import SwiftUI

enum MenuBarLayout {
    static let statusItemWidth: CGFloat = 196
}

@MainActor
final class MenuBarController: NSObject {
    private let store: MonitorStore
    private let statusItem = NSStatusBar.system.statusItem(
        withLength: MenuBarLayout.statusItemWidth
    )
    private var hostingView: NSHostingView<MenuBarContentView>?
    private var refreshItem: NSMenuItem?
    private var cancellables: Set<AnyCancellable> = []

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
        let refreshItem = menu.addItem(
            withTitle: "刷新数据",
            action: #selector(refresh),
            keyEquivalent: "r"
        )
        refreshItem.target = self
        self.refreshItem = refreshItem
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 Codex Monitor", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu

        store.$refreshState
            .sink { [weak self] state in
                self?.updateRefreshItem(state)
            }
            .store(in: &cancellables)
    }

    @objc private func refresh() {
        store.requestRefresh()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func updateRefreshItem(_ state: RefreshState) {
        switch state {
        case .idle:
            refreshItem?.title = "刷新数据"
        case .refreshing:
            refreshItem?.title = "正在刷新…"
        case .updated:
            refreshItem?.title = "已更新 · 再次刷新"
        case .failed:
            refreshItem?.title = "刷新失败 · 重试"
        }
    }
}
