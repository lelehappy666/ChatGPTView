import Combine
import SwiftUI

enum MenuAnimationTiming {
    static let zeroHoldNanoseconds: UInt64 = 60_000_000
    static let numberDuration = 1.2
    static let chartDuration = 1.0
}

@MainActor
final class MenuNumberAnimationContext: ObservableObject {
    @Published private(set) var cycle = 0
    @Published private(set) var isPresented = false

    func beginPresentation() {
        isPresented = true
        cycle &+= 1
    }

    func endPresentation() {
        isPresented = false
    }
}

enum MenuNumberAnimationPlan {
    static func initialValue(
        targetValue: Double,
        reduceMotion: Bool
    ) -> Double {
        reduceMotion ? targetValue : 0
    }
}

enum MenuNumberFormat: Equatable {
    case integer
    case groupedInteger
    case percentage
    case tokens
    case days
    case duration
    case resetCountdown

    func string(for value: Double) -> String {
        let safeValue = max(0, value)
        let roundedValue = Int(safeValue.rounded())

        switch self {
        case .integer:
            return String(roundedValue)
        case .groupedInteger:
            return roundedValue.formatted()
        case .percentage:
            return "\(roundedValue)%"
        case .tokens:
            return MetricFormatter.tokens(roundedValue)
        case .days:
            return "\(roundedValue) 天"
        case .duration:
            return MetricFormatter.duration(safeValue)
        case .resetCountdown:
            let totalHours = roundedValue / 3_600
            return "\(totalHours / 24) 天 \(totalHours % 24) 小时"
        }
    }
}

struct MenuInterpolatingNumberText: View, @preconcurrency Animatable {
    var value: Double
    let format: MenuNumberFormat

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var renderedText: String {
        format.string(for: value)
    }

    var body: some View {
        Text(renderedText)
    }
}

struct MenuRollingNumberText: View {
    let value: Double?
    let format: MenuNumberFormat

    @EnvironmentObject private var animationContext: MenuNumberAnimationContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedValue: Double
    @State private var animationTask: Task<Void, Never>?

    init(value: Double?, format: MenuNumberFormat) {
        self.value = value
        self.format = format
        _displayedValue = State(initialValue: value ?? 0)
    }

    var body: some View {
        Group {
            if let value {
                MenuInterpolatingNumberText(
                    value: displayedValue,
                    format: format
                )
                .accessibilityLabel(format.string(for: value))
            } else {
                Text("—")
                    .accessibilityLabel("暂无数据")
            }
        }
        .onAppear {
            if animationContext.isPresented {
                replayFromZero()
            } else {
                stopAndReset()
            }
        }
        .onChange(of: animationContext.cycle) {
            if animationContext.isPresented {
                replayFromZero()
            }
        }
        .onChange(of: animationContext.isPresented) {
            if !animationContext.isPresented {
                stopAndReset()
            }
        }
        .onChange(of: value) {
            animateToTarget()
        }
        .onChange(of: reduceMotion) {
            replayFromZero()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }

    private func replayFromZero() {
        animationTask?.cancel()
        animationTask = nil

        guard let value else {
            setWithoutAnimation(0)
            return
        }

        let initialValue = MenuNumberAnimationPlan.initialValue(
            targetValue: value,
            reduceMotion: reduceMotion
        )
        setWithoutAnimation(initialValue)

        guard initialValue != value else { return }

        animationTask = Task { @MainActor in
            try? await Task.sleep(
                nanoseconds: MenuAnimationTiming.zeroHoldNanoseconds
            )
            guard !Task.isCancelled else { return }
            withAnimation(
                .easeOut(duration: MenuAnimationTiming.numberDuration)
            ) {
                displayedValue = value
            }
        }
    }

    private func animateToTarget() {
        animationTask?.cancel()
        animationTask = nil

        guard let value else {
            setWithoutAnimation(0)
            return
        }

        guard !reduceMotion else {
            setWithoutAnimation(value)
            return
        }

        withAnimation(
            .easeOut(duration: MenuAnimationTiming.numberDuration)
        ) {
            displayedValue = value
        }
    }

    private func stopAndReset() {
        animationTask?.cancel()
        animationTask = nil
        setWithoutAnimation(0)
    }

    private func setWithoutAnimation(_ value: Double) {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            displayedValue = value
        }
    }
}
