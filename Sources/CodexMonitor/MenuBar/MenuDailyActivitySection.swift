import SwiftUI

enum MenuLocalUsagePresentation: Equatable {
    case empty
    case metrics

    static func make(snapshot: MonitorSnapshot) -> Self {
        snapshot.lastUpdatedAt == nil ? .empty : .metrics
    }
}

enum MenuDailyActivityPresentation {
    static func todayActivity(
        in days: [UsageDay],
        at now: Date = .now,
        calendar: Calendar = .current
    ) -> UsageDay? {
        days.first { calendar.isDate($0.date, inSameDayAs: now) }
    }
}

enum MenuActivityGrid {
    static func days(
        from input: [UsageDay],
        calendar: Calendar = .current,
        today: Date = .now
    ) -> [UsageDay] {
        let end = calendar.startOfDay(for: today)
        let weekday = calendar.component(.weekday, from: end)
        let daysSinceMonday = (weekday + 5) % 7
        let currentWeekMonday = calendar.date(
            byAdding: .day,
            value: -daysSinceMonday,
            to: end
        ) ?? end
        let start = calendar.date(
            byAdding: .day,
            value: -15 * 7,
            to: currentWeekMonday
        ) ?? currentWeekMonday
        let indexed = Dictionary(
            uniqueKeysWithValues: input.map {
                (calendar.startOfDay(for: $0.date), $0)
            }
        )
        return (0..<112).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            return indexed[date] ?? UsageDay(date: date, tokens: 0, sessions: 0)
        }
    }
}

struct MenuDailyActivitySection: View {
    let snapshot: MonitorSnapshot

    private var today: UsageDay? {
        MenuDailyActivityPresentation.todayActivity(in: snapshot.dailyActivity)
    }

    private var averageTokens: Int {
        guard !snapshot.dailyActivity.isEmpty else { return 0 }
        return snapshot.dailyActivity.reduce(0) { $0 + $1.tokens }
            / snapshot.dailyActivity.count
    }

    var body: some View {
        MenuDashboardSectionCard {
            VStack(alignment: .leading, spacing: 5) {
                MenuDashboardSectionHeader(
                    title: "每日活动",
                    subtitle: "最近 8 周"
                ) {
                    EmptyView()
                }

                if MenuLocalUsagePresentation.make(snapshot: snapshot) == .empty {
                    MenuLocalUsageEmptyState()
                } else {
                    HStack(spacing: 12) {
                        MenuReferenceActivityHeatmap(days: snapshot.dailyActivity)
                            .frame(width: 205)

                        Divider()

                        VStack(spacing: 0) {
                            MenuActivityMetric(
                                icon: "clock",
                                value: MetricFormatter.tokens(today?.tokens ?? 0),
                                label: "今天"
                            )
                            Divider()
                            MenuActivityMetric(
                                icon: "person.2",
                                value: "\(today?.sessions ?? 0)",
                                label: "会话"
                            )
                            Divider()
                            MenuActivityMetric(
                                icon: "chart.xyaxis.line",
                                value: MetricFormatter.tokens(averageTokens),
                                label: "平均/天"
                            )
                            Divider()
                            MenuActivityMetric(
                                icon: "flame",
                                value: "\(snapshot.currentStreakDays) 天",
                                label: "连续使用"
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

private struct MenuReferenceActivityHeatmap: View {
    let days: [UsageDay]
    @State private var hoveredDay: UsageDay?

    private var gridDays: [UsageDay] {
        MenuActivityGrid.days(from: days)
    }

    private var maximumTokens: Int {
        max(1, gridDays.map(\.tokens).max() ?? 1)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            VStack(alignment: .trailing, spacing: 7) {
                Text("周一")
                Text("周三")
                Text("周五")
                Text("周日")
            }
            .font(.system(size: 6.5))
            .foregroundStyle(.secondary)
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                LazyHGrid(
                    rows: Array(
                        repeating: GridItem(.fixed(8), spacing: 2),
                        count: 7
                    ),
                    spacing: 2
                ) {
                    ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                        RoundedRectangle(cornerRadius: 1.4)
                            .fill(color(for: day.tokens))
                            .frame(width: 8, height: 8)
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                hoveredDay = MenuActivityHoverSelection.next(
                                    current: hoveredDay,
                                    day: day,
                                    isHovered: hovering
                                )
                            }
                    }
                }
                .frame(width: 158, height: 68, alignment: .leading)

                MenuActivityHoverReadout(day: hoveredDay)
            }
        }
    }

    private func color(for tokens: Int) -> Color {
        guard tokens > 0 else { return Color.white.opacity(0.10) }
        return MenuDashboardVisual.accent.opacity(
            0.28 + 0.72 * min(1, Double(tokens) / Double(maximumTokens))
        )
    }
}

enum MenuActivityHoverSelection {
    static func next(
        current: UsageDay?,
        day: UsageDay,
        isHovered: Bool
    ) -> UsageDay? {
        if isHovered {
            return day
        }
        return current == day ? nil : current
    }
}

struct MenuActivityHoverReadout: View {
    let day: UsageDay?

    var body: some View {
        Group {
            if let day {
                Text(ActivityTooltip.text(for: day))
            } else {
                MenuActivityLegend()
            }
        }
        .font(.system(size: 6.5))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .frame(width: 158, height: 9, alignment: .leading)
    }
}

private struct MenuActivityLegend: View {
    var body: some View {
        HStack(spacing: 3) {
            Text("少")
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        MenuDashboardVisual.accent.opacity(
                            0.25 + Double(index) * 0.22
                        )
                    )
                    .frame(width: 6, height: 6)
            }
            Text("多")
        }
    }
}

struct MenuLocalUsageEmptyState: View {
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "tray")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("暂无本地使用数据")
                    .font(.system(size: 10, weight: .semibold))
                Text("完成首次刷新后显示活动与统计")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct MenuActivityMetric: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .frame(width: 12)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(MenuDashboardVisual.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, minHeight: 18)
    }
}
