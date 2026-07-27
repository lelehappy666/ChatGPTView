import XCTest
@testable import CodexMonitor

final class MenuPopoverLayoutTests: XCTestCase {
    func testUsesCompactTargetSizeWhenScreenHasEnoughSpace() {
        let size = MenuPopoverLayout.contentSize(
            for: CGRect(x: 0, y: 0, width: 1440, height: 1000)
        )
        XCTAssertEqual(size, CGSize(width: 640, height: 630))
    }

    func testClampsHeightAndWidthToVisibleScreen() {
        let size = MenuPopoverLayout.contentSize(
            for: CGRect(x: 0, y: 0, width: 600, height: 580)
        )
        XCTAssertEqual(size, CGSize(width: 576, height: 556))
    }

    func testZeroVisibleFrameDoesNotProduceNegativeContentSize() {
        let size = MenuPopoverLayout.contentSize(for: .zero)

        XCTAssertEqual(size, .zero)
    }

    func testCompactRowsFitInsideAvailableContentHeight() {
        let plan = MenuDashboardLayoutPlan.make(contentHeight: 558)

        XCTAssertEqual(
            plan.firstRowHeight + plan.projectRowHeight
                + plan.thirdRowHeight + plan.rowSpacing * 2,
            558,
            accuracy: 0.001
        )
    }

    func testOpeningHiddenPopoverRequestsRefresh() {
        XCTAssertTrue(MenuPopoverOpenPolicy.shouldRefresh(isShown: false))
        XCTAssertFalse(MenuPopoverOpenPolicy.shouldRefresh(isShown: true))
    }
}
