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
            resetText = "\(seconds / 86_400) 天 \((seconds % 86_400) / 3_600) 小时"
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

    private var quota: MenuWeeklyQuotaPresentation {
        .make(quota: snapshot.weeklyQuota, now: now)
    }

    private var refreshPresentation: QuotaRefreshPresentation {
        .make(
            refreshState: refreshState,
            hasQuota: snapshot.weeklyQuota.remainingPercent != nil,
            isFresh: quota.isFresh
        )
    }

    var body: some View {
        MenuDashboardSectionCard {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("本周额度")
                        .font(.system(size: 12, weight: .semibold))

                    Button(action: onRefresh) {
                        HStack(spacing: 4) {
                            if refreshPresentation.showsProgress {
                                ProgressView().controlSize(.mini)
                            } else {
                                Circle()
                                    .fill(
                                        quota.isFresh
                                            ? MenuDashboardVisual.success
                                            : MenuDashboardVisual.accent
                                    )
                                    .frame(width: 5, height: 5)
                            }
                            Text(refreshPresentation.title)
                        }
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(
                            quota.isFresh
                                ? MenuDashboardVisual.success
                                : Color.secondary
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!refreshPresentation.isEnabled)
                    .help("点击重新扫描 Codex 本地额度数据")
                    Spacer()
                }

                HStack(spacing: 18) {
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(quota.remainingText)
                            .font(.system(size: 29, weight: .bold, design: .rounded))
                            .foregroundStyle(MenuDashboardVisual.accent)
                        if quota.showsRemainingUnit {
                            Text("%")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text("剩余额度")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 112, alignment: .leading)

                    VStack(spacing: 7) {
                        HStack {
                            Text("本周已用")
                            Text(quota.usedText)
                                .foregroundStyle(MenuDashboardVisual.accent)
                            Spacer()
                        }

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.12))
                                if let usedFraction = quota.usedFraction {
                                    Capsule()
                                        .fill(MenuDashboardVisual.accent)
                                        .frame(width: proxy.size.width * usedFraction)
                                }
                            }
                        }
                        .frame(height: 5)

                        HStack {
                            Text("距离重置")
                            Text(quota.resetText)
                                .foregroundStyle(MenuDashboardVisual.accent)
                            Spacer()
                        }
                    }
                    .font(.system(size: 8.5))
                }
            }
        }
        .onReceive(freshnessTimer) { now = $0 }
    }
}
