import XCTest
@testable import CodexMonitor

final class LayoutContractTests: XCTestCase {
    func testDashboardContractLeavesStatisticsSafetySpace() {
        XCTAssertEqual(NotchLayout.size, CGSize(width: 420, height: 260))
        XCTAssertGreaterThanOrEqual(NotchLayout.statisticsBottomSafeArea, 14)
        XCTAssertEqual(NotchLayout.pageCount, 3)
    }

    func testMetricFormattingMatchesCompactChineseDesign() {
        XCTAssertEqual(MetricFormatter.tokens(1_130_000_000), "11.3 亿")
        XCTAssertEqual(MetricFormatter.tokens(310_000_000), "3.1 亿")
        XCTAssertEqual(MetricFormatter.tokens(142_000), "14.2 万")
        XCTAssertEqual(MetricFormatter.duration(11_760), "3 小时 16 分")
    }
}
