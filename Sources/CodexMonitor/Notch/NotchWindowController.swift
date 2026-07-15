import AppKit
import SwiftUI

@MainActor
final class NotchWindowController {
    private let store: MonitorStore
    private let panel: NSPanel
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var openTask: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?

    init(store: MonitorStore) {
        self.store = store
        panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: NotchLayout.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configurePanel()
    }

    func start() {
        guard localMonitor == nil, globalMonitor == nil else { return }

        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged]
        ) { [weak self] event in
            self?.evaluatePointer()
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.evaluatePointer()
            }
        }
    }

    func stop() {
        openTask?.cancel()
        closeTask?.cancel()
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
        panel.orderOut(nil)
    }

    private func configurePanel() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: NotchRootView(store: store))
    }

    private func evaluatePointer() {
        let point = NSEvent.mouseLocation
        guard let screen = screen(containing: point) else {
            scheduleClose()
            return
        }

        let isInside = NotchGeometry.hoverRect(screen: screen.frame).contains(point) ||
            (panel.isVisible && panel.frame.contains(point))

        if isInside {
            closeTask?.cancel()
            closeTask = nil
            if !panel.isVisible { scheduleOpen(on: screen) }
        } else {
            openTask?.cancel()
            openTask = nil
            if panel.isVisible { scheduleClose() }
        }
    }

    private func scheduleOpen(on screen: NSScreen) {
        guard openTask == nil else { return }
        openTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled, let self else { return }
            openTask = nil
            let point = NSEvent.mouseLocation
            guard NotchGeometry.hoverRect(screen: screen.frame).contains(point) else { return }
            show(on: screen)
        }
    }

    private func scheduleClose() {
        guard closeTask == nil else { return }
        closeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled, let self else { return }
            closeTask = nil
            hide()
        }
    }

    private func show(on screen: NSScreen) {
        guard NotchRefreshPolicy.shouldRequestRefresh(
            isPanelVisible: panel.isVisible
        ) else { return }
        store.requestRefresh()

        let fullFrame = NotchGeometry.panelFrame(screen: screen.frame)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        panel.setFrame(reduceMotion ? fullFrame : NotchGeometry.collapsedFrame(screen: screen.frame), display: true)
        panel.alphaValue = reduceMotion ? 0 : 1
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.14 : 0.32
            context.timingFunction = CAMediaTimingFunction(
                name: reduceMotion ? .easeOut : .easeInEaseOut
            )
            panel.animator().setFrame(fullFrame, display: true)
            panel.animator().alphaValue = 1
        }
    }

    private func hide() {
        guard let screen = screen(containing: panel.frame.center) else {
            panel.orderOut(nil)
            return
        }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let target = reduceMotion ? panel.frame : NotchGeometry.collapsedFrame(screen: screen.frame)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.12 : 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(target, display: true)
            if reduceMotion { panel.animator().alphaValue = 0 }
        } completionHandler: { [weak panel] in
            Task { @MainActor in
                panel?.orderOut(nil)
                panel?.alphaValue = 1
            }
        }
    }

    private func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }
}

enum NotchRefreshPolicy {
    static func shouldRequestRefresh(isPanelVisible: Bool) -> Bool {
        !isPanelVisible
    }
}

private struct NotchRootView: View {
    @ObservedObject var store: MonitorStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NotchDashboardView(snapshot: store.snapshot, reduceMotion: reduceMotion)
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
