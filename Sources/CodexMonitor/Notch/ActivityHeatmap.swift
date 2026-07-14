import SwiftUI

struct ActivityHeatmap: View {
    let days: [UsageDay]

    @State private var hoveredDay: UsageDay?

    private var paddedDays: [UsageDay] {
        ActivityGrid.days(from: days)
    }

    private var maximumTokens: Int {
        max(1, paddedDays.map(\.tokens).max() ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            LazyHGrid(
                rows: Array(repeating: GridItem(.fixed(11), spacing: 3), count: 7),
                spacing: 3
            ) {
                ForEach(Array(paddedDays.enumerated()), id: \.offset) { _, day in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: day.tokens))
                        .frame(width: 11, height: 11)
                        .contentShape(Rectangle())
                        .onHover { isHovered in
                            if isHovered {
                                hoveredDay = day
                            } else if hoveredDay == day {
                                hoveredDay = nil
                            }
                        }
                }
            }
            .frame(width: 142, height: 95, alignment: .leading)

            Group {
                if let hoveredDay {
                    Text(ActivityTooltip.text(for: hoveredDay))
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                } else {
                    ActivityLegend()
                }
            }
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
            .frame(width: 142, height: 12, alignment: .leading)
        }
        .frame(width: 142, alignment: .leading)
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

private struct ActivityLegend: View {
    var body: some View {
        HStack(spacing: 3) {
            Text("少")
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        Color(
                            red: 0.30 + Double(index) * 0.16,
                            green: 0.27 + Double(index) * 0.12,
                            blue: 0.42 + Double(index) * 0.18
                        )
                    )
                    .frame(width: 8, height: 8)
            }
            Text("多")
        }
    }
}
