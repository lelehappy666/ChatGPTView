import SwiftUI

struct DailyActivityPage: View {
    let snapshot: MonitorSnapshot

    private var today: UsageDay? { snapshot.dailyActivity.last }
    private var averageTokens: Int {
        guard !snapshot.dailyActivity.isEmpty else { return 0 }
        return snapshot.dailyActivity.reduce(0) { $0 + $1.tokens } / snapshot.dailyActivity.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            DashboardHeader(title: "每日活动", subtitle: "最近 8 周 · 每格代表一天", trailing: "56 天")

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    ActivityHeatmap(days: snapshot.dailyActivity)
                    HStack(spacing: 3) {
                        Text("少")
                        ForEach(0..<3, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color(red: 0.30 + Double(index) * 0.16, green: 0.27 + Double(index) * 0.12, blue: 0.42 + Double(index) * 0.18))
                                .frame(width: 8, height: 8)
                        }
                        Text("多")
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                }
                .frame(width: 142, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 5) {
                    Text("今天").font(.system(size: 10)).foregroundStyle(.secondary)
                    Text(MetricFormatter.tokens(today?.tokens ?? 0))
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                    MetricRow(label: "会话", value: "\(today?.sessions ?? 0)")
                    MetricRow(label: "平均/天", value: MetricFormatter.tokens(averageTokens))
                    MetricRow(label: "连续使用", value: "\(snapshot.currentStreakDays) 天")
                }
                .padding(.leading, 15)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 106)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .frame(width: NotchLayout.size.width, height: NotchLayout.pageContentHeight, alignment: .top)
    }
}

private struct MetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(value).fontWeight(.semibold)
        }
        .font(.system(size: 10))
        .lineLimit(1)
    }
}
