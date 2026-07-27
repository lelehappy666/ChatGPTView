import XCTest
@testable import CodexMonitor

final class MenuHoverCoordinatorTests: XCTestCase {
    func testStatusEntrySchedulesOpenAndCancelsPendingClose() {
        var coordinator = MenuHoverCoordinator()

        XCTAssertEqual(
            coordinator.statusHoverChanged(
                isInside: true,
                isPopoverShown: false
            ),
            [.cancelClose, .scheduleOpen]
        )
    }

    func testStatusExitBeforeOpenCancelsPendingOpen() {
        var coordinator = MenuHoverCoordinator()
        _ = coordinator.statusHoverChanged(
            isInside: true,
            isPopoverShown: false
        )

        XCTAssertEqual(
            coordinator.statusHoverChanged(
                isInside: false,
                isPopoverShown: false
            ),
            [.cancelOpen]
        )
    }

    func testPanelEntryCancelsStatusToPanelBridgeClose() {
        var coordinator = MenuHoverCoordinator()
        _ = coordinator.statusHoverChanged(
            isInside: true,
            isPopoverShown: true
        )
        coordinator.popoverDidShow()

        XCTAssertEqual(
            coordinator.statusHoverChanged(
                isInside: false,
                isPopoverShown: true
            ),
            [.cancelOpen, .scheduleClose(delay: .statusToPanel)]
        )
        XCTAssertEqual(
            coordinator.panelHoverChanged(
                isInside: true,
                isPopoverShown: true
            ),
            [.cancelClose]
        )
    }

    func testInitialPanelOutsideEventDoesNotCloseBeforePanelEntry() {
        var coordinator = MenuHoverCoordinator()
        coordinator.popoverDidShow()

        XCTAssertEqual(
            coordinator.panelHoverChanged(
                isInside: false,
                isPopoverShown: true
            ),
            []
        )
    }

    func testLeavingEnteredPanelSchedulesPanelExitClose() {
        var coordinator = MenuHoverCoordinator()
        coordinator.popoverDidShow()
        _ = coordinator.panelHoverChanged(
            isInside: true,
            isPopoverShown: true
        )

        XCTAssertEqual(
            coordinator.panelHoverChanged(
                isInside: false,
                isPopoverShown: true
            ),
            [.scheduleClose(delay: .panelExit)]
        )
    }

    func testPanelExitDoesNotCloseWhileStatusRemainsHovered() {
        var coordinator = MenuHoverCoordinator()
        _ = coordinator.statusHoverChanged(
            isInside: true,
            isPopoverShown: true
        )
        coordinator.popoverDidShow()
        _ = coordinator.panelHoverChanged(
            isInside: true,
            isPopoverShown: true
        )

        XCTAssertEqual(
            coordinator.panelHoverChanged(
                isInside: false,
                isPopoverShown: true
            ),
            []
        )
    }
}
