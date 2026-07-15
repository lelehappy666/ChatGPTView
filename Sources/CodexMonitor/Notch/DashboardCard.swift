import SwiftUI

struct DashboardCard<Content: View>: View {
    let padding: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        padding: CGFloat = 12,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                Color.white.opacity(0.032),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.085), lineWidth: 0.8)
            )
    }
}
