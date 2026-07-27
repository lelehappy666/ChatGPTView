import XCTest
@testable import CodexMonitor

final class MenuRollingNumberTests: XCTestCase {
    func testAnimationTimingKeepsNumbersReadable() {
        XCTAssertEqual(MenuAnimationTiming.numberDuration, 1.2)
        XCTAssertEqual(MenuAnimationTiming.chartDuration, 1.0)
    }

    @MainActor
    func testEveryPresentationAdvancesAnimationCycle() {
        let context = MenuNumberAnimationContext()

        XCTAssertEqual(context.cycle, 0)

        context.beginPresentation()
        context.beginPresentation()

        XCTAssertEqual(context.cycle, 2)
    }

    func testAnimatedPresentationStartsAtZeroValue() {
        XCTAssertEqual(
            MenuNumberAnimationPlan.initialValue(
                targetValue: 85,
                reduceMotion: false
            ),
            0
        )
    }

    func testReducedMotionStartsAtFinalValue() {
        XCTAssertEqual(
            MenuNumberAnimationPlan.initialValue(
                targetValue: 160,
                reduceMotion: true
            ),
            160
        )
    }

    func testNumberFormatsRenderIntermediateRealtimeValues() {
        XCTAssertEqual(MenuNumberFormat.integer.string(for: 44), "44")
        XCTAssertEqual(MenuNumberFormat.groupedInteger.string(for: 1_284), "1,284")
        XCTAssertEqual(MenuNumberFormat.percentage.string(for: 66), "66%")
        XCTAssertEqual(MenuNumberFormat.tokens.string(for: 50_000), "5 万")
        XCTAssertEqual(MenuNumberFormat.days.string(for: 3), "3 天")
        XCTAssertEqual(
            MenuNumberFormat.duration.string(for: 6_900),
            "1 小时 55 分"
        )
        XCTAssertEqual(
            MenuNumberFormat.resetCountdown.string(for: 183_600),
            "2 天 3 小时"
        )
    }

    @MainActor
    func testAnimatableTextUsesInterpolatedValueInsteadOfFinalString() {
        var text = MenuInterpolatingNumberText(
            value: 100,
            format: .percentage
        )

        text.animatableData = 50

        XCTAssertEqual(text.renderedText, "50%")
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
