import SwiftUI

struct GitHubContributionHeatmap: View {
    let days: [GitHubContributionDay]
    let onHover: (GitHubContributionDay?) -> Void

    @State private var hoveredDay: GitHubContributionDay?

    var body: some View {
        GeometryReader { proxy in
            let cells = GitHubContributionRenderPlan.cells(
                days: displayDays,
                width: proxy.size.width,
                height: proxy.size.height,
                spacing: 1.25
            )

            Canvas(opaque: false, rendersAsynchronously: true) { context, _ in
                for cell in cells {
                    let path = Path(
                        roundedRect: cell.rect,
                        cornerRadius: 1.4
                    )
                    context.fill(path, with: .color(color(level: cell.level)))
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    updateHover(
                        GitHubContributionRenderPlan.day(at: location, cells: cells)
                    )
                case .ended:
                    updateHover(nil)
                }
            }
        }
        .accessibilityLabel("GitHub 贡献热力图")
        .accessibilityValue("最近 12 个月共 \(days.reduce(0) { $0 + $1.contributionCount }) 次贡献")
    }

    private var displayDays: [GitHubContributionDay] {
        days.isEmpty ? Self.placeholderDays : days
    }

    private func color(level: Int) -> Color {
        switch level {
        case 1: return Color(red: 0.22, green: 0.21, blue: 0.27)
        case 2: return Color(red: 0.37, green: 0.33, blue: 0.50)
        case 3: return Color(red: 0.52, green: 0.45, blue: 0.73)
        case 4: return Color(red: 0.70, green: 0.63, blue: 0.98)
        default: return Color.white.opacity(0.10)
        }
    }

    private func updateHover(_ day: GitHubContributionDay?) {
        guard hoveredDay != day else { return }
        hoveredDay = day
        onHover(day)
    }

    private static let placeholderDays: [GitHubContributionDay] = {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: .now)
        return (0..<371).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 370, to: today).map {
                GitHubContributionDay(date: $0, contributionCount: 0)
            }
        }
    }()
}
