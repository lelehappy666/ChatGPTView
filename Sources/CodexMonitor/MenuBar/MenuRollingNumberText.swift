import Combine
import SwiftUI

enum MenuAnimationTiming {
    static let numberDuration = 1.2
    static let chartDuration = 1.0
}

@MainActor
final class MenuNumberAnimationContext: ObservableObject {
    @Published private(set) var cycle = 0

    func beginPresentation() {
        cycle &+= 1
    }
}

enum MenuNumberAnimationPlan {
    static func initialText(
        targetText: String,
        zeroText: String,
        reduceMotion: Bool
    ) -> String {
        guard targetText != "—" else { return targetText }
        return reduceMotion ? targetText : zeroText
    }
}

struct MenuRollingNumberText: View {
    let targetText: String
    let zeroText: String

    @EnvironmentObject private var animationContext: MenuNumberAnimationContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedText: String
    @State private var animationTask: Task<Void, Never>?

    init(targetText: String, zeroText: String) {
        self.targetText = targetText
        self.zeroText = zeroText
        _displayedText = State(initialValue: targetText)
    }

    var body: some View {
        Text(displayedText)
            .contentTransition(.numericText())
            .accessibilityLabel(targetText)
            .onAppear(perform: replayFromZero)
            .onChange(of: animationContext.cycle) {
                replayFromZero()
            }
            .onChange(of: targetText) {
                animateToTarget()
            }
            .onDisappear {
                animationTask?.cancel()
                animationTask = nil
            }
    }

    private func replayFromZero() {
        animationTask?.cancel()
        let initialText = MenuNumberAnimationPlan.initialText(
            targetText: targetText,
            zeroText: zeroText,
            reduceMotion: reduceMotion
        )
        setWithoutAnimation(initialText)

        guard initialText != targetText else {
            animationTask = nil
            return
        }

        animationTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            withAnimation(
                .easeOut(duration: MenuAnimationTiming.numberDuration)
            ) {
                displayedText = targetText
            }
        }
    }

    private func animateToTarget() {
        animationTask?.cancel()
        animationTask = nil

        guard !reduceMotion, targetText != "—" else {
            setWithoutAnimation(targetText)
            return
        }

        withAnimation(
            .easeOut(duration: MenuAnimationTiming.numberDuration)
        ) {
            displayedText = targetText
        }
    }

    private func setWithoutAnimation(_ text: String) {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            displayedText = text
        }
    }
}
