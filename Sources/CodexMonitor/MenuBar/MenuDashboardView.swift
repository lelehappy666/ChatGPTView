import SwiftUI

enum MenuDashboardSection: Hashable {
    case weeklyQuota
    case dailyActivity
    case projectAnalytics
    case statistics
    case github
}

enum MenuDashboardComposition {
    static let rows: [[MenuDashboardSection]] = [
        [.weeklyQuota, .dailyActivity],
        [.projectAnalytics],
        [.statistics, .github]
    ]

    static let sections = rows.flatMap { $0 }
}

struct MenuDashboardView: View {
    @ObservedObject var store: MonitorStore
    let onClose: () -> Void
    let onQuit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var githubStore = GitHubActivityStore()

    var body: some View {
        VStack(spacing: 0) {
            dashboardHeader
                .frame(height: 44)

            GeometryReader { proxy in
                let horizontalPadding: CGFloat = 12
                let verticalPadding: CGFloat = 12
                let innerWidth = max(0, proxy.size.width - horizontalPadding * 2)
                let plan = MenuDashboardLayoutPlan.make(
                    contentHeight: max(0, proxy.size.height - verticalPadding * 2)
                )

                VStack(spacing: plan.rowSpacing) {
                    HStack(spacing: plan.rowSpacing) {
                        sectionView(for: .weeklyQuota)
                        sectionView(for: .dailyActivity)
                    }
                    .frame(height: plan.firstRowHeight)

                    sectionView(for: .projectAnalytics)
                        .frame(height: plan.projectRowHeight)

                    HStack(spacing: plan.rowSpacing) {
                        sectionView(for: .statistics)
                            .frame(
                                width: max(
                                    0,
                                    (innerWidth - plan.rowSpacing) * 0.36
                                )
                            )
                        sectionView(for: .github)
                    }
                    .frame(height: plan.thirdRowHeight)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
            }

            dashboardFooter
                .frame(height: 28)
        }
        .foregroundStyle(Color.white)
        .environment(\.colorScheme, .dark)
        .background(Color.black)
        .onAppear {
            githubStore.primeFromCache()
        }
        .task {
            await githubStore.loadIfNeeded()
        }
    }

    private var dashboardHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Codex Monitor")
                    .font(.system(size: 16, weight: .bold))
                Text(refreshStatusText)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: store.requestRefresh) {
                Label("刷新", systemImage: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .background(Color.white.opacity(0.075), in: Capsule())
            .help("刷新数据 ⌘R")

            Button(action: onClose) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .background(Color.white.opacity(0.075), in: Circle())
            .help("收起面板")
        }
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.035))
    }

    private var dashboardFooter: some View {
        HStack(spacing: 14) {
            Text("每 30 秒自动刷新")
                .foregroundStyle(.secondary)
            Spacer()
            Button("刷新数据 ⌘R", action: store.requestRefresh)
                .keyboardShortcut("r", modifiers: .command)
            Button("退出 ⌘Q", action: onQuit)
                .keyboardShortcut("q", modifiers: .command)
        }
        .font(.system(size: 10, weight: .medium))
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.035))
    }

    @ViewBuilder
    private func sectionView(for section: MenuDashboardSection) -> some View {
        switch section {
        case .weeklyQuota:
            MenuWeeklyQuotaSection(
                snapshot: store.snapshot,
                refreshState: store.refreshState,
                onRefresh: store.requestRefresh
            )
        case .dailyActivity:
            MenuDailyActivitySection(snapshot: store.snapshot)
        case .projectAnalytics:
            MenuProjectAnalyticsSection(
                analytics: store.snapshot.projectAnalytics,
                reduceMotion: reduceMotion
            )
        case .statistics:
            MenuStatisticsSection(snapshot: store.snapshot)
        case .github:
            MenuGitHubActivitySection(store: githubStore)
        }
    }

    private var refreshStatusText: String {
        switch store.refreshState {
        case .idle:
            return "等待首次刷新"
        case .refreshing:
            return "正在刷新数据…"
        case .updated:
            return "数据已更新"
        case .failed:
            return "刷新失败，显示最近数据"
        }
    }
}
