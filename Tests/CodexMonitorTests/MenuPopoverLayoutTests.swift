import XCTest
@testable import CodexMonitor

final class MenuPopoverLayoutTests: XCTestCase {
    func testUsesReferenceTargetSizeWhenScreenHasEnoughSpace() {
        let size = MenuPopoverLayout.contentSize(
            for: CGRect(x: 0, y: 0, width: 1440, height: 1000)
        )
        XCTAssertEqual(size, CGSize(width: 420, height: 720))
    }

    func testSmallScreenPreservesReferenceAspectRatio() {
        let size = MenuPopoverLayout.contentSize(
            for: CGRect(x: 0, y: 0, width: 500, height: 600)
        )
        XCTAssertEqual(size.width / size.height, 420.0 / 720.0, accuracy: 0.001)
        XCTAssertLessThanOrEqual(size.width, 476)
        XCTAssertLessThanOrEqual(size.height, 576)
    }

    func testZeroVisibleFrameDoesNotProduceNegativeContentSize() {
        let size = MenuPopoverLayout.contentSize(for: .zero)

        XCTAssertEqual(size, .zero)
    }

    func testReferenceLayoutPlanFillsCanvasExactly() {
        let plan = MenuReferenceLayoutPlan()
        XCTAssertEqual(plan.totalHeight, MenuPopoverLayout.targetSize.height)
    }

    func testOpeningHiddenPopoverRequestsRefresh() {
        XCTAssertTrue(MenuPopoverOpenPolicy.shouldRefresh(isShown: false))
        XCTAssertFalse(MenuPopoverOpenPolicy.shouldRefresh(isShown: true))
    }
}
