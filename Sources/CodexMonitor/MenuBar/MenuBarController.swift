import AppKit
import SwiftUI

enum MenuBarLayout {
    static let statusItemWidth: CGFloat = 196
}

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let store: MonitorStore
    private let statusItem = NSStatusBar.system.statusItem(
        withLength: MenuBarLayout.statusItemWidth
    )
    private let popover = NSPopover()
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

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let rootView = MenuDashboardView(
            store: store,
            onClose: { [weak self] in self?.popover.performClose(nil) },
            onQuit: { NSApp.terminate(nil) }
        )
        popover.contentViewController = NSHostingController(rootView: rootView)

        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp])
        updateButtonAccessibility()
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }

        guard let button = statusItem.button else { return }
        let visibleFrame = button.window?.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? .zero
        popover.contentSize = MenuPopoverLayout.contentSize(for: visibleFrame)
        if MenuPopoverOpenPolicy.shouldRefresh(isShown: popover.isShown) {
            store.requestRefresh()
        }
        popover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )
    }

    func popoverDidShow(_ notification: Notification) {
        updateButtonAccessibility()
    }

    func popoverDidClose(_ notification: Notification) {
        updateButtonAccessibility()
    }

    private func updateButtonAccessibility() {
        guard let button = statusItem.button else { return }
        button.setAccessibilityLabel("Codex Monitor")
        button.setAccessibilityHelp(
            popover.isShown
                ? "收起 Codex Monitor 数据面板"
                : "打开 Codex Monitor 数据面板"
        )
        button.setAccessibilityExpanded(popover.isShown)
    }
}
