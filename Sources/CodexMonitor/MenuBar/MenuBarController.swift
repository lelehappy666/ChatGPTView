import AppKit
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
        let rootView = MenuDashboardView(
            store: store,
            onClose: { [weak self] in self?.popover.performClose(nil) },
            onQuit: { NSApp.terminate(nil) }
        )
        popover.contentViewController = NSHostingController(rootView: rootView)

        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp])
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
}
