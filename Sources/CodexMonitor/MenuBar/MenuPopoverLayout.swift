import Foundation

enum MenuPopoverLayout {
    static let targetSize = CGSize(width: 720, height: 840)
    static let screenInset: CGFloat = 24

    static func contentSize(for visibleFrame: CGRect) -> CGSize {
        CGSize(
            width: min(targetSize.width, visibleFrame.width - screenInset),
            height: min(targetSize.height, visibleFrame.height - screenInset)
        )
    }
}

enum MenuPopoverOpenPolicy {
    static func shouldRefresh(isShown: Bool) -> Bool {
        !isShown
    }
}
