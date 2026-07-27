import SwiftUI

enum MenuQuotaProgressAnimationPlan {
    static func normalized(_ progress: Double) -> Double {
        max(0, min(1, progress))
    }

    static func initialProgress(
        targetProgress: Double,
        reduceMotion: Bool
    ) -> Double {
        reduceMotion ? normalized(targetProgress) : 0
    }

    static func updateAction(
        isPresented: Bool,
        reduceMotion: Bool
    ) -> MenuNumberAnimationPlan.UpdateAction {
        MenuNumberAnimationPlan.updateAction(
            isPresented: isPresented,
            reduceMotion: reduceMotion
        )
    }
}

struct MenuInterpolatingQuotaProgress: View, @preconcurrency Animatable {
    var progress: Double
    let availableWidth: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var renderedWidth: CGFloat {
        max(0, availableWidth)
            * MenuQuotaProgressAnimationPlan.normalized(progress)
    }

    var body: some View {
        Capsule()
            .fill(MenuDashboardVisual.accent)
            .frame(width: renderedWidth)
    }
}

struct MenuAnimatedQuotaProgress: View {
    let targetProgress: Double?
    let availableWidth: CGFloat

    @EnvironmentObject private var animationContext: MenuNumberAnimationContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedProgress: Double
    @State private var animationTask: Task<Void, Never>?

    init(targetProgress: Double?, availableWidth: CGFloat) {
        self.targetProgress = targetProgress
        self.availableWidth = availableWidth
        _displayedProgress = State(initialValue: targetProgress ?? 0)
    }

    var body: some View {
        Group {
            if targetProgress != nil {
                MenuInterpolatingQuotaProgress(
                    progress: displayedProgress,
                    availableWidth: availableWidth
                )
            }
        }
        .accessibilityHidden(true)
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
        .onChange(of: targetProgress) {
            animateToTarget()
        }
        .onChange(of: reduceMotion) {
            if animationContext.isPresented {
                replayFromZero()
            } else {
                stopAndReset()
            }
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }

    private func replayFromZero() {
        animationTask?.cancel()
        animationTask = nil

        guard let targetProgress else {
            setWithoutAnimation(0)
            return
        }

        let target = MenuQuotaProgressAnimationPlan.normalized(targetProgress)
        let initialProgress = MenuQuotaProgressAnimationPlan.initialProgress(
            targetProgress: target,
            reduceMotion: reduceMotion
        )
        setWithoutAnimation(initialProgress)

        guard initialProgress != target else { return }

        animationTask = Task { @MainActor in
            try? await Task.sleep(
                nanoseconds: MenuAnimationTiming.zeroHoldNanoseconds
            )
            guard !Task.isCancelled else { return }
            withAnimation(
                .easeOut(duration: MenuAnimationTiming.numberDuration)
            ) {
                displayedProgress = target
            }
        }
    }

    private func animateToTarget() {
        animationTask?.cancel()
        animationTask = nil

        guard let targetProgress else {
            setWithoutAnimation(0)
            return
        }

        let target = MenuQuotaProgressAnimationPlan.normalized(targetProgress)
        switch MenuQuotaProgressAnimationPlan.updateAction(
            isPresented: animationContext.isPresented,
            reduceMotion: reduceMotion
        ) {
        case .holdZero:
            stopAndReset()
        case .setTarget:
            setWithoutAnimation(target)
        case .animateToTarget:
            withAnimation(
                .easeOut(duration: MenuAnimationTiming.numberDuration)
            ) {
                displayedProgress = target
            }
        }
    }

    private func stopAndReset() {
        animationTask?.cancel()
        animationTask = nil
        setWithoutAnimation(0)
    }

    private func setWithoutAnimation(_ progress: Double) {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            displayedProgress = progress
        }
    }
}
