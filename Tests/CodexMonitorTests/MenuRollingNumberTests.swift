import XCTest
@testable import CodexMonitor

final class MenuRollingNumberTests: XCTestCase {
    @MainActor
    func testEveryPresentationAdvancesAnimationCycle() {
        let context = MenuNumberAnimationContext()

        XCTAssertEqual(context.cycle, 0)

        context.beginPresentation()
        context.beginPresentation()

        XCTAssertEqual(context.cycle, 2)
    }

    func testAnimatedPresentationStartsAtMatchingZeroText() {
        XCTAssertEqual(
            MenuNumberAnimationPlan.initialText(
                targetText: "85%",
                zeroText: "0%",
                reduceMotion: false
            ),
            "0%"
        )
    }

    func testReducedMotionStartsAtFinalText() {
        XCTAssertEqual(
            MenuNumberAnimationPlan.initialText(
                targetText: "6 天 16 小时",
                zeroText: "0 天 0 小时",
                reduceMotion: true
            ),
            "6 天 16 小时"
        )
    }

    func testPlaceholderNeverAnimatesFromNumericZero() {
        XCTAssertEqual(
            MenuNumberAnimationPlan.initialText(
                targetText: "—",
                zeroText: "0",
                reduceMotion: false
            ),
            "—"
        )
    }

    func testAnimatedChartPresentationStartsAtZeroProgress() {
        XCTAssertEqual(
            MenuChartAnimationPlan.initialProgress(
                targetProgress: 0.72,
                reduceMotion: false
            ),
            0
        )
    }

    func testReducedMotionChartStartsAtTargetProgress() {
        XCTAssertEqual(
            MenuChartAnimationPlan.initialProgress(
                targetProgress: 0.72,
                reduceMotion: true
            ),
            0.72
        )
    }
}
