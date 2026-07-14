import AppKit
import SwiftUI

enum PageNavigation {
    static func target(from current: Int, delta: CGFloat) -> Int {
        guard abs(delta) >= 12 else { return current }
        if delta < 0 {
            return min(current + 1, NotchLayout.pageCount - 1)
        }
        return max(current - 1, 0)
    }
}

struct WheelPagingCapture: NSViewRepresentable {
    @Binding var page: Int

    func makeNSView(context: Context) -> PagingEventView {
        let view = PagingEventView()
        view.onPageDelta = { delta in
            page = PageNavigation.target(from: page, delta: delta)
        }
        return view
    }

    func updateNSView(_ nsView: PagingEventView, context: Context) {
        nsView.onPageDelta = { delta in
            page = PageNavigation.target(from: page, delta: delta)
        }
    }
}

final class PagingEventView: NSView {
    var onPageDelta: ((CGFloat) -> Void)?
    private var lastTrigger = Date.distantPast

    override func scrollWheel(with event: NSEvent) {
        guard Date().timeIntervalSince(lastTrigger) >= 0.35 else { return }
        let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
            ? -event.scrollingDeltaX
            : event.scrollingDeltaY
        guard abs(delta) >= 12 else { return }
        lastTrigger = .now
        onPageDelta?(delta)
    }
}
