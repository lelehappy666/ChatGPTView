import SwiftUI

enum GitHubMenuPresentation: Equatable {
    case authorization(message: String?)
    case loading
    case content(snapshot: GitHubActivitySnapshot, statusMessage: String?)

    static func make(state: GitHubActivityStore.State) -> Self {
        switch state {
        case .unbound(let message):
            .authorization(message: message)
        case .loading(let cached):
            if let cached {
                .content(snapshot: cached, statusMessage: "正在刷新")
            } else {
                .loading
            }
        case .loaded(let snapshot):
            .content(snapshot: snapshot, statusMessage: nil)
        case .failed(let message, let cached):
            if let cached {
                .content(snapshot: cached, statusMessage: message)
            } else {
                .authorization(message: message)
            }
        }
    }
}

enum MenuGitHubMonthLabelPlan {
    static func titles(
        days: [GitHubContributionDay],
        calendar: Calendar = .current
    ) -> [String] {
        var lastKey: DateComponents?
        let titles = days.sorted { $0.date < $1.date }.compactMap { day -> String? in
            let key = calendar.dateComponents([.year, .month], from: day.date)
            guard key != lastKey else { return nil }
            lastKey = key
            guard let month = key.month else { return nil }
            return "\(month)月"
        }
        return Array(titles.suffix(7))
    }
}

struct MenuGitHubActivitySection: View {
    @ObservedObject private var store: GitHubActivityStore

    init(store: GitHubActivityStore) {
        self.store = store
    }

    var body: some View {
        MenuDashboardSectionCard {
            switch GitHubMenuPresentation.make(state: store.state) {
            case .authorization(let message):
                GitHubAuthorizationCard(message: message) { token in
                    await store.bind(token: token)
                }
                .scaleEffect(0.78)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loading:
                VStack(alignment: .leading, spacing: 8) {
                    Text("GitHub 活跃")
                        .font(.system(size: 12, weight: .semibold))
                    ProgressView("正在加载 GitHub 活动…")
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

            case .content(let snapshot, let statusMessage):
                MenuGitHubActivityContent(
                    snapshot: snapshot,
                    statusMessage: statusMessage,
                    onRefresh: { Task { await store.refresh() } },
                    onDisconnect: store.disconnect
                )
            }
        }
    }
}

private struct MenuGitHubActivityContent: View {
    let snapshot: GitHubActivitySnapshot
    let statusMessage: String?
    let onRefresh: () -> Void
    let onDisconnect: () -> Void

    @State private var hoveredContributionDay: GitHubContributionDay?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("GitHub 活跃")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8, weight: .semibold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .background(Color.white.opacity(0.065), in: Circle())
                .help("刷新 GitHub 数据")

                Button(action: onRefresh) {
                    HStack(spacing: 4) {
                        Text(snapshot.username)
                            .lineLimit(1)
                        Circle()
                            .fill(MenuDashboardVisual.success)
                            .frame(width: 5, height: 5)
                    }
                    .font(.system(size: 8, weight: .medium))
                    .padding(.horizontal, 7)
                    .frame(height: 20)
                    .background(
                        Color.white.opacity(0.065),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("解除绑定", role: .destructive, action: onDisconnect)
                }
            }

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    MenuRollingNumberText(
                        value: Double(snapshot.totalContributions),
                        format: .groupedInteger
                    )
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(MenuDashboardVisual.accent)
                    Text("次贡献")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 74, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 0) {
                        ForEach(
                            MenuGitHubMonthLabelPlan.titles(
                                days: snapshot.contributionDays
                            ),
                            id: \.self
                        ) { title in
                            Text(title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .font(.system(size: 5.8))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                    HStack(spacing: 3) {
                        VStack(spacing: 6) {
                            Text("周一")
                            Text("周三")
                            Text("周五")
                        }
                        .font(.system(size: 5.8))
                        .foregroundStyle(.secondary)

                        GitHubContributionHeatmap(
                            days: snapshot.contributionDays,
                            onHover: { hoveredContributionDay = $0 }
                        )
                        .frame(height: 39)
                    }

                    HStack {
                        if let hoveredContributionDay {
                            Text(GitHubContributionTooltip.text(for: hoveredContributionDay))
                                .lineLimit(1)
                        } else if let statusMessage {
                            Text(statusMessage)
                                .foregroundStyle(Color.orange)
                        } else {
                            Spacer()
                            Text("少  ■ ■ ■ ■  多")
                        }
                    }
                    .font(.system(size: 6))
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 61)

            RecentRepositoryGrid(
                repositories: snapshot.repositories,
                density: .reference
            )
            .frame(
                height: RepositoryGridMetrics.make(density: .reference).totalHeight,
                alignment: .top
            )
        }
    }
}
