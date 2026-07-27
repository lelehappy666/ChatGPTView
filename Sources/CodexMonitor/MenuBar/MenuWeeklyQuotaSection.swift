import Combine
import SwiftUI

struct MenuWeeklyQuotaPresentation: Equatable {
    let remainingText: String
    let showsRemainingUnit: Bool
    let usedText: String
    let usedFraction: Double?
    let resetText: String

    static func make(quota: WeeklyQuota, now: Date) -> Self {
        guard let remaining = QuotaFreshnessPolicy.visibleRemainingPercent(
            for: quota,
            at: now
        ) else {
            return Self(
                remainingText: "—",
                showsRemainingUnit: false,
                usedText: "—",
                usedFraction: nil,
                resetText: "—"
            )
        }

        let usedPercent = max(0, min(100, 100 - remaining))
        let resetText: String
        if let resetDate = quota.resetsAt {
            let seconds = max(0, Int(resetDate.timeIntervalSince(now)))
            let days = seconds / 86_400
            let hours = (seconds % 86_400) / 3_600
            resetText = "\(days) 天 \(hours) 小时"
        } else {
            resetText = "—"
        }

        return Self(
            remainingText: String(Int(remaining.rounded())),
            showsRemainingUnit: true,
            usedText: "\(Int(usedPercent.rounded()))%",
            usedFraction: usedPercent / 100,
            resetText: resetText
        )
    }
}

struct MenuWeeklyQuotaSection: View {
    let snapshot: MonitorSnapshot
    let refreshState: RefreshState
    let onRefresh: () -> Void

    @State private var now = Date.now

    private let freshnessTimer = Timer.publish(
        every: 30,
        on: .main,
        in: .common
    ).autoconnect()

    private var quotaPresentation: MenuWeeklyQuotaPresentation {
        .make(
            quota: snapshot.weeklyQuota,
            now: now
        )
    }

    private var refreshPresentation: QuotaRefreshPresentation {
        .make(
            refreshState: refreshState,
            hasQuota: snapshot.weeklyQuota.remainingPercent != nil,
            isFresh: quotaPresentation.usedFraction != nil
        )
    }

    var body: some View {
        MenuDashboardSectionCard {
            VStack(alignment: .leading, spacing: 16) {
                MenuDashboardSectionHeader(
                    title: "本周额度",
                    subtitle: "Codex 本地额度数据"
                ) {
                    Button(action: onRefresh) {
                        HStack(spacing: 6) {
                            if refreshPresentation.showsProgress {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(refreshPresentation.title)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MenuDashboardVisual.success)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!refreshPresentation.isEnabled)
                    .background(
                        Color.white.opacity(0.075),
                        in: Capsule()
                    )
                    .help("立即重新扫描 Codex 本地额度数据")
                }

                HStack(alignment: .center, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("剩余额度")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(quotaPresentation.remainingText)
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                            if quotaPresentation.showsRemainingUnit {
                                Text("%")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(width: 146, alignment: .leading)

                    VStack(alignment: .leading, spacing: 11) {
                        HStack {
                            Text("本周已用")
                            Spacer()
                            Text(quotaPresentation.usedText)
                                .fontWeight(.semibold)
                        }

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.10))
                                if let usedFraction = quotaPresentation.usedFraction {
                                    Capsule()
                                        .fill(MenuDashboardVisual.accent)
                                        .frame(width: proxy.size.width * usedFraction)
                                }
                            }
                        }
                        .frame(height: 9)

                        HStack {
                            Text("距离重置")
                            Spacer()
                            Text(quotaPresentation.resetText)
                                .fontWeight(.semibold)
                        }
                    }
                    .font(.system(size: 11))
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onReceive(freshnessTimer) { now in
            self.now = now
        }
    }
}
