import SwiftUI

struct StatisticsPage: View {
    let snapshot: MonitorSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            DashboardHeader(title: "统计总览", subtitle: "全部历史数据", trailing: "累计")

            HStack(spacing: 7) {
                PrimaryStatistic(value: MetricFormatter.tokens(snapshot.lifetimeTokens), label: "累计 Token 数")
                PrimaryStatistic(value: MetricFormatter.tokens(snapshot.peakTokens), label: "峰值 Token 数")
            }
            .frame(height: 39)

            HStack(spacing: 6) {
                SecondaryStatistic(
                    value: MetricFormatter.duration(snapshot.longestTaskDuration),
                    label: "最长任务时长"
                )
                .frame(width: 124)
                SecondaryStatistic(value: "\(snapshot.currentStreakDays) 天", label: "当前连续天数")
                SecondaryStatistic(value: "\(snapshot.longestStreakDays) 天", label: "最长连续天数")
            }
            .frame(height: 27)
        }
        .padding(.horizontal, 18)
        .offset(y: -3)
        .frame(width: 328, height: 129, alignment: .top)
    }
}

private struct PrimaryStatistic: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).lineLimit(1)
            Text(label).font(.system(size: 7)).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08)))
    }
}

private struct SecondaryStatistic: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 9, weight: .semibold)).lineLimit(1)
            Text(label).font(.system(size: 6.5)).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(.horizontal, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08)))
    }
}
