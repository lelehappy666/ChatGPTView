import Combine
import SwiftUI

struct WeeklyQuotaPage: View {
    let snapshot: MonitorSnapshot

    @State private var now = Date.now
    @State private var hoveredRecentDay: UsageDay?

    private let freshnessTimer = Timer.publish(
        every: 30,
        on: .main,
        in: .common
    ).autoconnect()

    private var remaining: Double? {
        QuotaFreshnessPolicy.visibleRemainingPercent(
            for: snapshot.weeklyQuota,
            at: now
        )
    }
    private var used: Double { max(0, min(100, 100 - (remaining ?? 100))) }
    private var recentDays: [UsageDay] {
        Array(ActivityGrid.days(from: snapshot.dailyActivity).suffix(7))
    }
    private var maximumRecentTokens: Int { max(1, recentDays.map(\.tokens).max() ?? 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardHeader(title: "本周额度", subtitle: "Weekly usage limit", trailing: syncText)

            HStack(spacing: 10) {
                DashboardCard {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("剩余额度")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text(remaining.map { String(Int($0.rounded())) } ?? "—")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                            if remaining != nil {
                                Text("%")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                DashboardCard {
                    VStack(spacing: 10) {
                        HStack {
                            Text("本周已用").foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(used.rounded()))%").fontWeight(.semibold)
                        }

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.10))
                                Capsule()
                                    .fill(Color(red: 0.64, green: 0.57, blue: 0.94))
                                    .frame(width: proxy.size.width * used / 100)
                            }
                        }
                        .frame(height: 8)

                        HStack {
                            Text("距离重置").foregroundStyle(.secondary)
                            Spacer()
                            Text(resetText).fontWeight(.semibold)
                        }
                    }
                    .font(.system(size: 10))
                }
            }
            .frame(height: 98)

            DashboardCard(padding: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("最近 7 天")
                            .font(.system(size: 9, weight: .semibold))
                        Spacer()
                        Text(
                            hoveredRecentDay.map {
                                ActivityTooltip.tokenText(for: $0)
                            } ?? "每日 Token"
                        )
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(recentDays.enumerated()), id: \.offset) { _, day in
                            VStack(spacing: 3) {
                                Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        day.tokens > 0
                                            ? Color(red: 0.61, green: 0.54, blue: 0.90)
                                            : Color.white.opacity(0.09)
                                    )
                                    .frame(
                                        height: max(
                                            4,
                                            28 * CGFloat(day.tokens) /
                                                CGFloat(maximumRecentTokens)
                                        )
                                    )
                                Text(weekday(for: day.date))
                                    .font(.system(size: 7))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onHover { isHovered in
                                if isHovered {
                                    hoveredRecentDay = day
                                } else if hoveredRecentDay == day {
                                    hoveredRecentDay = nil
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: 76)
        }
        .padding(.horizontal, 22)
        .frame(width: NotchLayout.size.width, height: NotchLayout.pageContentHeight, alignment: .top)
        .onReceive(freshnessTimer) { now in
            self.now = now
        }
    }

    private var syncText: String {
        if snapshot.weeklyQuota.remainingPercent == nil {
            return "暂不可用"
        }
        return remaining == nil ? "等待 Codex 更新" : "● 已同步"
    }

    private var resetText: String {
        guard let date = snapshot.weeklyQuota.resetsAt else { return "—" }
        let seconds = max(0, Int(date.timeIntervalSinceNow))
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        return "\(days) 天 \(hours) 小时"
    }

    private func weekday(for date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).weekday(.narrow))
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
                Text(subtitle).font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Spacer()
            Text(trailing)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(red: 0.49, green: 0.90, blue: 0.73))
        }
        .frame(height: 32)
    }
}
