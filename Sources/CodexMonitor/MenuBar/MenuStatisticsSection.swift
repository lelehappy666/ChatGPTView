import SwiftUI

struct MenuStatisticsSection: View {
    let snapshot: MonitorSnapshot

    private var localUsagePresentation: MenuLocalUsagePresentation {
        .make(snapshot: snapshot)
    }

    var body: some View {
        MenuDashboardSectionCard {
            VStack(alignment: .leading, spacing: 16) {
                MenuDashboardSectionHeader(
                    title: "统计总览",
                    subtitle: "全部历史数据"
                ) {
                    Text("累计")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                if localUsagePresentation == .empty {
                    MenuLocalUsageEmptyState()
                } else {
                    HStack(spacing: 10) {
                        MenuStatisticMetric(
                            value: MetricFormatter.tokens(snapshot.lifetimeTokens),
                            label: "累计 Token"
                        )
                        MenuStatisticMetric(
                            value: MetricFormatter.tokens(snapshot.peakTokens),
                            label: "峰值 Token"
                        )
                        MenuStatisticMetric(
                            value: MetricFormatter.duration(snapshot.longestTaskDuration),
                            label: "最长任务时长"
                        )
                        MenuStatisticMetric(
                            value: "\(snapshot.currentStreakDays) 天",
                            label: "当前连续天数"
                        )
                        MenuStatisticMetric(
                            value: "\(snapshot.longestStreakDays) 天",
                            label: "最长连续天数"
                        )
                    }
                }
            }
        }
    }
}

private struct MenuStatisticMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.60)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.white.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 10)
        )
    }
}
