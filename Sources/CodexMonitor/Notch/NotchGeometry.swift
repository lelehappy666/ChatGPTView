import Foundation

enum NotchGeometry {
    static func panelFrame(
        screen: CGRect,
        panelSize: CGSize = NotchLayout.size
    ) -> CGRect {
        CGRect(
            x: screen.midX - panelSize.width / 2,
            y: screen.maxY - panelSize.height,
            width: panelSize.width,
            height: panelSize.height
        )
    }

    static func hoverRect(
        screen: CGRect,
        notchWidth: CGFloat = 164,
        height: CGFloat = 34
    ) -> CGRect {
        CGRect(
            x: screen.midX - notchWidth / 2,
            y: screen.maxY - height,
            width: notchWidth,
            height: height
        )
    }

    static func collapsedFrame(screen: CGRect) -> CGRect {
        CGRect(
            x: screen.midX - 82,
            y: screen.maxY - 31,
            width: 164,
            height: 31
        )
    }
}
