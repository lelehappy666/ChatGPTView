import Foundation

enum MenuPopoverLayout {
    static let targetSize = CGSize(width: 640, height: 630)
    static let screenInset: CGFloat = 24

    static func contentSize(for visibleFrame: CGRect) -> CGSize {
        CGSize(
            width: max(
                0,
                min(targetSize.width, visibleFrame.width - screenInset)
            ),
            height: max(
                0,
                min(targetSize.height, visibleFrame.height - screenInset)
            )
        )
    }
}

struct MenuDashboardLayoutPlan: Equatable {
    let firstRowHeight: CGFloat
    let projectRowHeight: CGFloat
    let thirdRowHeight: CGFloat
    let rowSpacing: CGFloat

    static func make(contentHeight: CGFloat) -> Self {
        let rowSpacing: CGFloat = 8
        let usableHeight = max(0, contentHeight - rowSpacing * 2)
        let firstRowHeight = min(138, usableHeight)
        let remainingAfterFirst = max(0, usableHeight - firstRowHeight)
        let projectRowHeight = min(180, remainingAfterFirst)

        return Self(
            firstRowHeight: firstRowHeight,
            projectRowHeight: projectRowHeight,
            thirdRowHeight: max(
                0,
                usableHeight - firstRowHeight - projectRowHeight
            ),
            rowSpacing: rowSpacing
        )
    }
}

enum MenuPopoverOpenPolicy {
    static func shouldRefresh(isShown: Bool) -> Bool {
        !isShown
    }
}
