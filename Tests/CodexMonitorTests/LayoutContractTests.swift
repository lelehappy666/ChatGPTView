import XCTest
@testable import CodexMonitor

final class LayoutContractTests: XCTestCase {
    func testMenuPopoverContentSizeFitsVisibleScreen() {
        XCTAssertEqual(
            MenuPopoverLayout.contentSize(
                for: CGRect(x: 0, y: 0, width: 800, height: 700)
            ),
            CGSize(width: 720, height: 676)
        )
    }

    func testMetricFormattingMatchesCompactChineseDesign() {
        XCTAssertEqual(MetricFormatter.tokens(1_130_000_000), "11.3 亿")
        XCTAssertEqual(MetricFormatter.tokens(310_000_000), "3.1 亿")
        XCTAssertEqual(MetricFormatter.tokens(142_000), "14.2 万")
        XCTAssertEqual(MetricFormatter.duration(11_760), "3 小时 16 分")
    }
}
