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

struct MenuDailyActivitySection: View {
    let snapshot: MonitorSnapshot

    private var localUsagePresentation: MenuLocalUsagePresentation {
        .make(snapshot: snapshot)
    }

    private var today: UsageDay? {
        MenuDailyActivityPresentation.todayActivity(in: snapshot.dailyActivity)
    }

    private var averageTokens: Int {
        guard !snapshot.dailyActivity.isEmpty else { return 0 }
        return snapshot.dailyActivity.reduce(0) { $0 + $1.tokens } / snapshot.dailyActivity.count
    }

    var body: some View {
        MenuDashboardSectionCard {
            VStack(alignment: .leading, spacing: 8) {
                MenuDashboardSectionHeader(
                    title: "每日活动",
                    subtitle: "最近 8 周"
                ) {
                    Text("56 天")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                if localUsagePresentation == .empty {
                    MenuLocalUsageEmptyState()
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        ActivityHeatmap(
                            days: snapshot.dailyActivity,
                            density: .compact
                        )

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8)
                            ],
                            alignment: .leading,
                            spacing: 6
                        ) {
                            MenuActivityMetric(
                                value: MetricFormatter.tokens(today?.tokens ?? 0),
                                label: "今日 Token"
                            )
                            MenuActivityMetric(
                                value: "\(today?.sessions ?? 0)",
                                label: "今日会话"
                            )
                            MenuActivityMetric(
                                value: MetricFormatter.tokens(averageTokens),
                                label: "平均/天"
                            )
                            MenuActivityMetric(
                                value: "\(snapshot.currentStreakDays) 天",
                                label: "连续使用"
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
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
                    .font(.system(size: 11, weight: .semibold))
                Text("完成首次刷新后显示活动与统计")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

private struct MenuActivityMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
