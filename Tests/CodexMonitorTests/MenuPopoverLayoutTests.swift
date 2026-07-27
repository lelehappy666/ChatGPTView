import XCTest
@testable import CodexMonitor

final class MenuPopoverLayoutTests: XCTestCase {
    func testUsesTargetSizeWhenScreenHasEnoughSpace() {
        let size = MenuPopoverLayout.contentSize(
            for: CGRect(x: 0, y: 0, width: 1440, height: 1000)
        )
        XCTAssertEqual(size, CGSize(width: 720, height: 840))
    }

    func testClampsHeightAndWidthToVisibleScreen() {
        let size = MenuPopoverLayout.contentSize(
            for: CGRect(x: 0, y: 0, width: 700, height: 760)
        )
        XCTAssertEqual(size, CGSize(width: 676, height: 736))
    }

    func testOpeningHiddenPopoverRequestsRefresh() {
        XCTAssertTrue(MenuPopoverOpenPolicy.shouldRefresh(isShown: false))
        XCTAssertFalse(MenuPopoverOpenPolicy.shouldRefresh(isShown: true))
    }
}
