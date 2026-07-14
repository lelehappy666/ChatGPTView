import SwiftUI

struct ActivityHeatmap: View {
    let days: [UsageDay]

    private var paddedDays: [UsageDay] {
        let visible = Array(days.suffix(56))
        let missing = max(0, 56 - visible.count)
        let placeholders = (0..<missing).map {
            UsageDay(date: Date(timeIntervalSince1970: Double($0)), tokens: 0, sessions: 0)
        }
        return placeholders + visible
    }

    private var maximumTokens: Int {
        max(1, paddedDays.map(\.tokens).max() ?? 1)
    }

    var body: some View {
        LazyHGrid(
            rows: Array(repeating: GridItem(.fixed(11), spacing: 3), count: 7),
            spacing: 3
        ) {
            ForEach(Array(paddedDays.enumerated()), id: \.offset) { _, day in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color(for: day.tokens))
                    .frame(width: 11, height: 11)
                    .help(day.tokens == 0 ? "无活动" : MetricFormatter.tokens(day.tokens))
            }
        }
        .frame(width: 142, height: 95, alignment: .leading)
    }

    private func color(for tokens: Int) -> Color {
        guard tokens > 0 else { return Color.white.opacity(0.10) }
        let ratio = Double(tokens) / Double(maximumTokens)
        switch ratio {
        case ..<0.25: return Color(red: 0.25, green: 0.23, blue: 0.34)
        case ..<0.50: return Color(red: 0.34, green: 0.30, blue: 0.48)
        case ..<0.75: return Color(red: 0.49, green: 0.43, blue: 0.69)
        default: return Color(red: 0.66, green: 0.59, blue: 0.91)
        }
    }
}
