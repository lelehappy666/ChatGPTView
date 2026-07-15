import SwiftUI

struct DailyActivityPage: View {
    let snapshot: MonitorSnapshot

    private var today: UsageDay? { snapshot.dailyActivity.last }
    private var averageTokens: Int {
        guard !snapshot.dailyActivity.isEmpty else { return 0 }
        return snapshot.dailyActivity.reduce(0) { $0 + $1.tokens } / snapshot.dailyActivity.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardHeader(title: "每日活动", subtitle: "最近 8 周 · 每格代表一天", trailing: "56 天")

            DashboardCard(padding: 10) {
                HStack(alignment: .top, spacing: 10) {
                    ActivityHeatmap(days: snapshot.dailyActivity)
                        .frame(width: 142, alignment: .topLeading)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("今天")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(MetricFormatter.tokens(today?.tokens ?? 0))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text("今日 Token")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 92, alignment: .topLeading)

                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 1, height: 72)

                    VStack(spacing: 12) {
                        DailyInlineMetric(
                            value: "\(today?.sessions ?? 0)",
                            label: "今日会话"
                        )
                        DailyInlineMetric(
                            value: DailyAverageComparison.text(
                                today: today?.tokens ?? 0,
                                average: averageTokens
                            ),
                            label: "较日均"
                        )
                    }
                    .padding(.top, 2)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .frame(height: 122)

            HStack(spacing: 8) {
                DailyMetricCard(value: "\(today?.sessions ?? 0)", label: "今日会话")
                DailyMetricCard(value: MetricFormatter.tokens(averageTokens), label: "平均/天")
                DailyMetricCard(value: "\(snapshot.currentStreakDays) 天", label: "连续使用")
            }
            .frame(height: 62)
        }
        .padding(.horizontal, 22)
        .frame(width: NotchLayout.size.width, height: NotchLayout.pageContentHeight, alignment: .top)
    }
}

private struct DailyInlineMetric: View {
    let value: String
    let label: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
            Spacer(minLength: 2)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}

private struct DailyMetricCard: View {
    let value: String
    let label: String

    var body: some View {
        DashboardCard(padding: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
