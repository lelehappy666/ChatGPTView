import AppKit
import SwiftUI

enum MenuBarLayout {
    static let statusItemWidth: CGFloat = 196
}

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate, AppSurfaceControlling {
    private let store: MonitorStore
    private let statusItem = NSStatusBar.system.statusItem(
        withLength: MenuBarLayout.statusItemWidth
    )
    private let popover = NSPopover()
    private let numberAnimationContext = MenuNumberAnimationContext()
    private var hostingView: NSHostingView<MenuBarContentView>?
    private var hoverCoordinator = MenuHoverCoordinator()
    private var hoverOpenTask: Task<Void, Never>?
    private var hoverCloseTask: Task<Void, Never>?

    init(store: MonitorStore) {
        self.store = store
        super.init()
    }

    func start() {
        guard let button = statusItem.button else { return }
        let hostingView = NSHostingView(
            rootView: MenuBarContentView(
                store: store,
                onHoverChanged: { [weak self] isInside in
                    self?.handleStatusHover(isInside)
                }
            )
        )
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
            numberAnimationContext: numberAnimationContext,
            onClose: { [weak self] in self?.closePopover() },
            onQuit: { NSApp.terminate(nil) },
            onHoverChanged: { [weak self] isInside in
                self?.handlePanelHover(isInside)
            }
        )
        popover.contentViewController = NSHostingController(rootView: rootView)

        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp])
        updateButtonAccessibility()
    }

    func stop() {
        cancelHoverTasks()
        popover.performClose(nil)
        hostingView?.removeFromSuperview()
        hostingView = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    @objc private func togglePopover(_ sender: Any?) {
        cancelHoverTasks()
        if popover.isShown {
            closePopover()
            return
        }
        showPopover()
    }

    private func showPopover() {
        guard !popover.isShown else { return }
        guard let button = statusItem.button else { return }
        let visibleFrame = button.window?.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? .zero
        popover.contentSize = MenuPopoverLayout.contentSize(for: visibleFrame)
        if MenuPopoverOpenPolicy.shouldRefresh(isShown: popover.isShown) {
            store.requestRefresh()
        }
        numberAnimationContext.beginPresentation()
        popover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )
    }

    func popoverDidShow(_ notification: Notification) {
        hoverCoordinator.popoverDidShow()
        updateButtonAccessibility()
    }

    func popoverDidClose(_ notification: Notification) {
        hoverOpenTask?.cancel()
        hoverOpenTask = nil
        hoverCloseTask?.cancel()
        hoverCloseTask = nil
        hoverCoordinator.popoverDidClose()
        updateButtonAccessibility()
    }

    private func closePopover() {
        hoverOpenTask?.cancel()
        hoverOpenTask = nil
        popover.performClose(nil)
    }

    private func handleStatusHover(_ isInside: Bool) {
        perform(
            hoverCoordinator.statusHoverChanged(
                isInside: isInside,
                isPopoverShown: popover.isShown
            )
        )
    }

    private func handlePanelHover(_ isInside: Bool) {
        perform(
            hoverCoordinator.panelHoverChanged(
                isInside: isInside,
                isPopoverShown: popover.isShown
            )
        )
    }

    private func perform(_ actions: [MenuHoverAction]) {
        for action in actions {
            switch action {
            case .scheduleOpen:
                hoverOpenTask?.cancel()
                hoverOpenTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(
                        nanoseconds: MenuHoverCoordinator.openDelayNanoseconds
                    )
                    guard !Task.isCancelled else { return }
                    self?.showPopover()
                }
            case .cancelOpen:
                hoverOpenTask?.cancel()
                hoverOpenTask = nil
            case .scheduleClose(let delay):
                hoverCloseTask?.cancel()
                hoverCloseTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: delay.nanoseconds)
                    guard !Task.isCancelled, let self else { return }
                    guard !hoverCoordinator.isStatusHovered,
                          !hoverCoordinator.isPanelHovered else {
                        return
                    }
                    closePopover()
                }
            case .cancelClose:
                hoverCloseTask?.cancel()
                hoverCloseTask = nil
            }
        }
    }

    private func cancelHoverTasks() {
        hoverOpenTask?.cancel()
        hoverOpenTask = nil
        hoverCloseTask?.cancel()
        hoverCloseTask = nil
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
