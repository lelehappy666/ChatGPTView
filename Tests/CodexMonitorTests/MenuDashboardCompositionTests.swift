import XCTest
@testable import CodexMonitor

final class MenuDashboardCompositionTests: XCTestCase {
    func testListsEachDashboardSectionOnceInDisplayOrder() {
        XCTAssertEqual(
            MenuDashboardComposition.sections,
            [.weeklyQuota, .dailyActivity, .projectAnalytics, .statistics, .github]
        )
        XCTAssertEqual(Set(MenuDashboardComposition.sections).count, 5)
    }
}
