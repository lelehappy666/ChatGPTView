import SwiftUI

struct StatisticsPage: View {
    let snapshot: MonitorSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardHeader(title: "统计总览", subtitle: "全部历史数据", trailing: "累计")

            HStack(spacing: 10) {
                DashboardCard {
                    PrimaryStatistic(
                        value: MetricFormatter.tokens(snapshot.lifetimeTokens),
                        label: "累计 Token 数"
                    )
                }
                DashboardCard {
                    PrimaryStatistic(
                        value: MetricFormatter.tokens(snapshot.peakTokens),
                        label: "峰值 Token 数"
                    )
                }
            }
            .frame(height: 92)

            HStack(spacing: 8) {
                DashboardCard(padding: 10) {
                    SecondaryStatistic(
                        value: MetricFormatter.duration(snapshot.longestTaskDuration),
                        label: "最长任务时长"
                    )
                }
                DashboardCard(padding: 10) {
                    SecondaryStatistic(
                        value: "\(snapshot.currentStreakDays) 天",
                        label: "当前连续天数"
                    )
                }
                DashboardCard(padding: 10) {
                    SecondaryStatistic(
                        value: "\(snapshot.longestStreakDays) 天",
                        label: "最长连续天数"
                    )
                }
            }
            .frame(height: 72)
        }
        .padding(.horizontal, 22)
        .frame(width: NotchLayout.size.width, height: NotchLayout.pageContentHeight, alignment: .top)
    }
}

private struct PrimaryStatistic: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}

private struct SecondaryStatistic: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
