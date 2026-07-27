import Foundation

enum MenuPopoverLayout {
    static let targetSize = CGSize(width: 420, height: 720)
    static let screenInset: CGFloat = 24

    static func scaleFactor(for availableSize: CGSize) -> CGFloat {
        guard targetSize.width > 0, targetSize.height > 0 else { return 0 }
        return max(
            0,
            min(
                1,
                availableSize.width / targetSize.width,
                availableSize.height / targetSize.height
            )
        )
    }

    static func contentSize(for visibleFrame: CGRect) -> CGSize {
        let availableSize = CGSize(
            width: max(0, visibleFrame.width - screenInset),
            height: max(0, visibleFrame.height - screenInset)
        )
        let scale = scaleFactor(for: availableSize)
        return CGSize(
            width: targetSize.width * scale,
            height: targetSize.height * scale
        )
    }
}

struct MenuReferenceLayoutPlan: Equatable {
    let headerHeight: CGFloat = 42
    let quotaHeight: CGFloat = 80
    let dailyHeight: CGFloat = 120
    let projectHeight: CGFloat = 130
    let statisticsHeight: CGFloat = 80
    let githubHeight: CGFloat = 182
    let footerHeight: CGFloat = 30
    let spacing: CGFloat = 6
    let padding: CGFloat = 10

    var totalHeight: CGFloat {
        headerHeight + quotaHeight + dailyHeight + projectHeight
            + statisticsHeight + githubHeight + footerHeight
            + spacing * 6 + padding * 2
    }
}

enum MenuPopoverOpenPolicy {
    static func shouldRefresh(isShown: Bool) -> Bool {
        !isShown
    }
}
