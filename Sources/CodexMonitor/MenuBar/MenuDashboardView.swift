import SwiftUI

enum MenuDashboardSection: Hashable {
    case weeklyQuota
    case dailyActivity
    case projectAnalytics
    case statistics
    case github
}

enum MenuDashboardComposition {
    static let sections: [MenuDashboardSection] = [
        .weeklyQuota,
        .dailyActivity,
        .projectAnalytics,
        .statistics,
        .github
    ]
}

enum MenuPopoverHoverAction: Equatable {
    case none
    case cancelClose
    case scheduleClose
}

struct MenuPopoverHoverState {
    private(set) var hasEntered = false

    mutating func update(isInside: Bool) -> MenuPopoverHoverAction {
        if isInside {
            hasEntered = true
            return .cancelClose
        }
        return hasEntered ? .scheduleClose : .none
    }
}

struct MenuDashboardView: View {
    @ObservedObject var store: MonitorStore
    let onClose: () -> Void
    let onQuit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var githubStore = GitHubActivityStore()
    @State private var popoverHoverState = MenuPopoverHoverState()
    @State private var autoCloseTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            let scale = MenuPopoverLayout.scaleFactor(for: proxy.size)
            referenceCanvas
                .scaleEffect(scale, anchor: .topLeading)
                .frame(
                    width: MenuPopoverLayout.targetSize.width * scale,
                    height: MenuPopoverLayout.targetSize.height * scale,
                    alignment: .topLeading
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
        }
        .foregroundStyle(Color.white)
        .environment(\.colorScheme, .dark)
        .background(Color.black)
        .contentShape(Rectangle())
        .onHover(perform: handlePopoverHover)
        .onAppear {
            githubStore.primeFromCache()
        }
        .task {
            await githubStore.loadIfNeeded()
        }
        .onDisappear {
            autoCloseTask?.cancel()
            autoCloseTask = nil
        }
    }

    private var referenceCanvas: some View {
        let plan = MenuReferenceLayoutPlan()
        return VStack(spacing: plan.spacing) {
            dashboardHeader.frame(height: plan.headerHeight)
            sectionView(for: .weeklyQuota).frame(height: plan.quotaHeight)
            sectionView(for: .dailyActivity).frame(height: plan.dailyHeight)
            sectionView(for: .projectAnalytics).frame(height: plan.projectHeight)
            sectionView(for: .statistics).frame(height: plan.statisticsHeight)
            sectionView(for: .github).frame(height: plan.githubHeight)
            dashboardFooter.frame(height: plan.footerHeight)
        }
        .padding(plan.padding)
        .frame(
            width: MenuPopoverLayout.targetSize.width,
            height: MenuPopoverLayout.targetSize.height,
            alignment: .top
        )
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.035, green: 0.045, blue: 0.065),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.22), lineWidth: 0.7)
        }
    }

    private var dashboardHeader: some View {
        HStack(spacing: 9) {
            OpenAIKnotMark(color: MenuDashboardVisual.accent)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text("Codex Monitor")
                    .font(.system(size: 13, weight: .semibold))
                HStack(spacing: 5) {
                    Circle()
                        .fill(MenuDashboardVisual.success)
                        .frame(width: 5, height: 5)
                    Text(refreshStatusText)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: store.requestRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MenuDashboardVisual.accent)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .background(Color.white.opacity(0.065), in: Circle())
            .help("刷新数据 ⌘R")

            Button(action: onClose) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .background(Color.white.opacity(0.065), in: Circle())
            .help("收起面板")
        }
        .padding(.horizontal, 4)
    }

    private var dashboardFooter: some View {
        HStack(spacing: 10) {
            Text("数据每 5 分钟自动刷新")
                .foregroundStyle(.secondary)
            Spacer()
            Button("⟳  刷新数据   ⌘R", action: store.requestRefresh)
                .keyboardShortcut("r", modifiers: .command)
            Divider().frame(height: 14)
            Button("退出   ⌘Q", action: onQuit)
                .keyboardShortcut("q", modifiers: .command)
        }
        .font(.system(size: 8, weight: .medium))
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
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
                dailyActivity: store.snapshot.dailyActivity,
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
            return "刚刚更新"
        case .failed:
            return "刷新失败，显示最近数据"
        }
    }

    private func handlePopoverHover(_ isInside: Bool) {
        switch popoverHoverState.update(isInside: isInside) {
        case .none:
            break
        case .cancelClose:
            autoCloseTask?.cancel()
            autoCloseTask = nil
        case .scheduleClose:
            autoCloseTask?.cancel()
            autoCloseTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                onClose()
            }
        }
    }
}
