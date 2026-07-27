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
