import Combine
import SwiftUI

struct MenuWeeklyQuotaPresentation: Equatable {
    let remainingText: String
    let showsRemainingUnit: Bool
    let usedText: String
    let usedFraction: Double?
    let resetText: String
    let isFresh: Bool

    static func make(quota: WeeklyQuota, now: Date) -> Self {
        let state = QuotaFreshnessPolicy.displayState(for: quota, at: now)
        guard let remaining = state.remainingPercent else {
            return Self(
                remainingText: "—",
                showsRemainingUnit: false,
                usedText: "—",
                usedFraction: nil,
                resetText: "—",
                isFresh: false
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
            resetText: resetText,
            isFresh: state.isFresh
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
            isFresh: quotaPresentation.isFresh
        )
    }

    var body: some View {
        MenuDashboardSectionCard {
            VStack(alignment: .leading, spacing: 8) {
                MenuDashboardSectionHeader(
                    title: "本周额度",
                    subtitle: "Codex 本地额度"
                ) {
                    Button(action: onRefresh) {
                        HStack(spacing: 4) {
                            if refreshPresentation.showsProgress {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(refreshPresentation.title)
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(MenuDashboardVisual.success)
                        .padding(.horizontal, 7)
                        .frame(height: 24)
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

                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("剩余额度")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(quotaPresentation.remainingText)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            if quotaPresentation.showsRemainingUnit {
                                Text("%")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(width: 82, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
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
                        .frame(height: 6)

                        HStack {
                            Text("距离重置")
                            Spacer()
                            Text(quotaPresentation.resetText)
                                .fontWeight(.semibold)
                        }
                    }
                    .font(.system(size: 9))
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onReceive(freshnessTimer) { now in
            self.now = now
        }
    }
}
