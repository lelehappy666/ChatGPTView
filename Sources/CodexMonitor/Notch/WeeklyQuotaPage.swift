import SwiftUI

struct WeeklyQuotaPage: View {
    let snapshot: MonitorSnapshot

    private var remaining: Double? { snapshot.weeklyQuota.remainingPercent }
    private var used: Double { max(0, min(100, 100 - (remaining ?? 100))) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardHeader(title: "本周额度", subtitle: "Weekly usage limit", trailing: syncText)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("剩余额度")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(remaining.map { String(Int($0.rounded())) } ?? "—")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                        Text("%")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 138, alignment: .leading)
                .overlay(alignment: .trailing) {
                    Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 68)
                }

                VStack(spacing: 9) {
                    HStack {
                        Text("本周已用").foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(used.rounded()))%").fontWeight(.semibold)
                    }
                    .font(.system(size: 10))

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule()
                                .fill(Color(red: 0.62, green: 0.55, blue: 0.95))
                                .frame(width: proxy.size.width * used / 100)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text("距离重置").foregroundStyle(.secondary)
                        Spacer()
                        Text(resetText).fontWeight(.semibold)
                    }
                    .font(.system(size: 10))
                }
            }

            HStack(spacing: 4) {
                ForEach(Array(snapshot.dailyActivity.suffix(7).enumerated()), id: \.offset) { _, day in
                    Capsule()
                        .fill(day.tokens > 0 ? Color(red: 0.58, green: 0.51, blue: 0.88) : Color.white.opacity(0.12))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 7)
        }
        .padding(.horizontal, 22)
        .frame(width: NotchLayout.size.width, height: NotchLayout.pageContentHeight, alignment: .top)
    }

    private var syncText: String {
        snapshot.lastUpdatedAt == nil ? "暂不可用" : "● 已同步"
    }

    private var resetText: String {
        guard let date = snapshot.weeklyQuota.resetsAt else { return "—" }
        let seconds = max(0, Int(date.timeIntervalSinceNow))
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        return "\(days) 天 \(hours) 小时"
    }
}

struct DashboardHeader: View {
    let title: String
    let subtitle: String
    let trailing: String

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
            Text(trailing)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(red: 0.49, green: 0.90, blue: 0.73))
        }
    }
}
