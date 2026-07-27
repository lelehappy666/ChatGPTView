import SwiftUI

struct MenuStatisticsSection: View {
    let snapshot: MonitorSnapshot

    var body: some View {
        MenuDashboardSectionCard {
            VStack(alignment: .leading, spacing: 5) {
                MenuDashboardSectionHeader(
                    title: "统计总览",
                    subtitle: nil
                ) {
                    EmptyView()
                }

                if MenuLocalUsagePresentation.make(snapshot: snapshot) == .empty {
                    MenuLocalUsageEmptyState()
                } else {
                    HStack(spacing: 7) {
                        metric(
                            icon: "cylinder.split.1x2",
                            value: MetricFormatter.tokens(snapshot.lifetimeTokens),
                            zeroValue: MetricFormatter.tokens(0),
                            label: "累计 Token 数"
                        )
                        metric(
                            icon: "chart.line.uptrend.xyaxis",
                            value: MetricFormatter.tokens(snapshot.peakTokens),
                            zeroValue: MetricFormatter.tokens(0),
                            label: "峰值 Token 数"
                        )
                        metric(
                            icon: "clock",
                            value: MetricFormatter.duration(snapshot.longestTaskDuration),
                            zeroValue: MetricFormatter.duration(0),
                            label: "最长任务时长"
                        )
                        metric(
                            icon: "calendar",
                            value: "\(snapshot.currentStreakDays) 天",
                            zeroValue: "0 天",
                            label: "当前连续天数"
                        )
                        metric(
                            icon: "medal.star",
                            value: "\(snapshot.longestStreakDays) 天",
                            zeroValue: "0 天",
                            label: "最长连续天数"
                        )
                    }
                }
            }
        }
    }

    private func metric(
        icon: String,
        value: String,
        zeroValue: String,
        label: String
    ) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(MenuDashboardVisual.accent)
            MenuRollingNumberText(
                targetText: value,
                zeroText: zeroValue
            )
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(MenuDashboardVisual.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
            Text(label)
                .font(.system(size: 6.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.white.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 5)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.6)
        }
    }
}
