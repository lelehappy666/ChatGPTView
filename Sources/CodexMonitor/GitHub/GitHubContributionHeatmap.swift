import SwiftUI

struct GitHubContributionHeatmap: View {
    let days: [GitHubContributionDay]

    private var maximum: Int {
        Swift.max(1, days.map(\.contributionCount).max() ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            LazyHGrid(
                rows: Array(repeating: GridItem(.fixed(4), spacing: 1), count: 7),
                spacing: 1
            ) {
                ForEach(displayDays) { day in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color(for: day.contributionCount))
                        .frame(width: 4, height: 4)
                        .help(tooltip(for: day))
                }
            }
            .frame(height: 34, alignment: .leading)

            HStack(spacing: 3) {
                Text("少")
                ForEach(0...4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color(level: level))
                        .frame(width: 5, height: 5)
                }
                Text("多")
            }
            .font(.system(size: 7))
            .foregroundStyle(.secondary)
        }
    }

    private var displayDays: [GitHubContributionDay] {
        guard days.isEmpty else { return days }
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: .now)
        return (0..<371).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 370, to: today).map {
                GitHubContributionDay(date: $0, contributionCount: 0)
            }
        }
    }

    private func color(for count: Int) -> Color {
        color(level: GitHubContributionScale.level(count: count, maximum: maximum))
    }

    private func color(level: Int) -> Color {
        switch level {
        case 1: return Color(red: 0.25, green: 0.23, blue: 0.34)
        case 2: return Color(red: 0.38, green: 0.33, blue: 0.53)
        case 3: return Color(red: 0.51, green: 0.44, blue: 0.72)
        case 4: return Color(red: 0.67, green: 0.60, blue: 0.94)
        default: return Color.white.opacity(0.10)
        }
    }

    private func tooltip(for day: GitHubContributionDay) -> String {
        let date = day.date.formatted(
            .dateTime.locale(Locale(identifier: "zh_CN")).month().day()
        )
        return "\(date) · \(day.contributionCount) 次贡献"
    }
}
