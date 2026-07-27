import SwiftUI

enum ActivityHeatmapDensity: Equatable {
    case standard
    case compact
}

struct ActivityHeatmapMetrics: Equatable {
    let rowCount: Int
    let cellSize: CGFloat
    let cellSpacing: CGFloat
    let width: CGFloat
    let legendSpacing: CGFloat
    let legendHeight: CGFloat
    let legendCellSize: CGFloat

    var gridHeight: CGFloat {
        CGFloat(rowCount) * cellSize
            + CGFloat(rowCount - 1) * cellSpacing
    }

    var totalHeight: CGFloat {
        gridHeight + legendSpacing + legendHeight
    }

    static func make(density: ActivityHeatmapDensity) -> Self {
        switch density {
        case .standard:
            Self(
                rowCount: 7,
                cellSize: 11,
                cellSpacing: 3,
                width: 142,
                legendSpacing: 5,
                legendHeight: 12,
                legendCellSize: 8
            )
        case .compact:
            Self(
                rowCount: 7,
                cellSize: 7,
                cellSpacing: 2,
                width: 86,
                legendSpacing: 4,
                legendHeight: 10,
                legendCellSize: 6
            )
        }
    }
}

struct ActivityHeatmap: View {
    let days: [UsageDay]
    let density: ActivityHeatmapDensity

    @State private var hoveredDay: UsageDay?

    init(
        days: [UsageDay],
        density: ActivityHeatmapDensity = .standard
    ) {
        self.days = days
        self.density = density
    }

    private var metrics: ActivityHeatmapMetrics {
        .make(density: density)
    }

    private var paddedDays: [UsageDay] {
        ActivityGrid.days(from: days)
    }

    private var maximumTokens: Int {
        max(1, paddedDays.map(\.tokens).max() ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.legendSpacing) {
            LazyHGrid(
                rows: Array(
                    repeating: GridItem(
                        .fixed(metrics.cellSize),
                        spacing: metrics.cellSpacing
                    ),
                    count: metrics.rowCount
                ),
                spacing: metrics.cellSpacing
            ) {
                ForEach(Array(paddedDays.enumerated()), id: \.offset) { _, day in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: day.tokens))
                        .frame(
                            width: metrics.cellSize,
                            height: metrics.cellSize
                        )
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
            .frame(
                width: metrics.width,
                height: metrics.gridHeight,
                alignment: .leading
            )

            Group {
                if let hoveredDay {
                    Text(ActivityTooltip.text(for: hoveredDay))
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                } else {
                    ActivityLegend(cellSize: metrics.legendCellSize)
                }
            }
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
            .frame(
                width: metrics.width,
                height: metrics.legendHeight,
                alignment: .leading
            )
        }
        .frame(
            width: metrics.width,
            height: metrics.totalHeight,
            alignment: .leading
        )
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
    let cellSize: CGFloat

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
                    .frame(width: cellSize, height: cellSize)
            }
            Text("多")
        }
    }
}
