import Combine
import SwiftUI

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

    private var remaining: Double? {
        QuotaFreshnessPolicy.visibleRemainingPercent(
            for: snapshot.weeklyQuota,
            at: now
        )
    }

    private var presentation: QuotaRefreshPresentation {
        .make(
            refreshState: refreshState,
            hasQuota: snapshot.weeklyQuota.remainingPercent != nil,
            isFresh: remaining != nil
        )
    }

    private var usedPercent: Double {
        max(0, min(100, 100 - (remaining ?? 100)))
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
                            if presentation.showsProgress {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(presentation.title)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MenuDashboardVisual.success)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!presentation.isEnabled)
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
                            Text(remaining.map { String(Int($0.rounded())) } ?? "—")
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                            if remaining != nil {
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
                            Text("\(Int(usedPercent.rounded()))%")
                                .fontWeight(.semibold)
                        }

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.10))
                                Capsule()
                                    .fill(MenuDashboardVisual.accent)
                                    .frame(width: proxy.size.width * usedPercent / 100)
                            }
                        }
                        .frame(height: 9)

                        HStack {
                            Text("距离重置")
                            Spacer()
                            Text(resetText)
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

    private var resetText: String {
        guard let date = snapshot.weeklyQuota.resetsAt else { return "—" }
        let seconds = max(0, Int(date.timeIntervalSinceNow))
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        return "\(days) 天 \(hours) 小时"
    }
}
