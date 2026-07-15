import XCTest
@testable import CodexMonitor

final class NotchGeometryTests: XCTestCase {
    func testPanelIsCenteredAtTopOfMainScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1_512, height: 982)

        let frame = NotchGeometry.panelFrame(screen: screen)

        XCTAssertEqual(frame, CGRect(x: 546, y: 622, width: 420, height: 360))
    }

    func testPanelUsesSecondaryScreenCoordinates() {
        let screen = CGRect(x: 1_512, y: 120, width: 1_920, height: 1_080)

        let frame = NotchGeometry.panelFrame(screen: screen)
        let hover = NotchGeometry.hoverRect(screen: screen)

        XCTAssertEqual(frame, CGRect(x: 2_262, y: 840, width: 420, height: 360))
        XCTAssertEqual(hover, CGRect(x: 2_390, y: 1_166, width: 164, height: 34))
    }
}
