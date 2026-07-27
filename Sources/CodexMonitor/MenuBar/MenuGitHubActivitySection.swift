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
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)

            case .loading:
                VStack(alignment: .leading, spacing: 16) {
                    MenuDashboardSectionHeader(
                        title: "GitHub 活跃",
                        subtitle: "正在加载"
                    ) {
                        Image(systemName: "cat.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(width: 28, height: 28)
                            .background(Color.white, in: Circle())
                    }

                    ProgressView("正在加载 GitHub 活动…")
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, minHeight: 76)
                }

            case .content(let snapshot, let statusMessage):
                MenuGitHubActivityContent(
                    snapshot: snapshot,
                    statusMessage: statusMessage,
                    onRefresh: {
                        Task { await store.refresh() }
                    },
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
        VStack(alignment: .leading, spacing: 14) {
            MenuDashboardSectionHeader(
                title: "GitHub 活跃",
                subtitle: statusMessage ?? "最近 12 个月"
            ) {
                HStack(spacing: 8) {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .background(Color.white.opacity(0.075), in: Circle())
                    .help("刷新 GitHub 数据")

                    Button(action: onRefresh) {
                        HStack(spacing: 6) {
                            Text(snapshot.username)
                                .lineLimit(1)
                            Circle()
                                .fill(MenuDashboardVisual.success)
                                .frame(width: 6, height: 6)
                        }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 9)
                        .frame(height: 28)
                        .background(
                            Color.white.opacity(0.075),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("解除绑定", role: .destructive, action: onDisconnect)
                    }
                    .help("右键可解除 GitHub 绑定")
                }
            }

            HStack(alignment: .lastTextBaseline) {
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text(snapshot.totalContributions.formatted())
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(MenuDashboardVisual.accent)
                    Text("次贡献")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let hoveredContributionDay {
                    Text(GitHubContributionTooltip.text(for: hoveredContributionDay))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                } else if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.orange)
                } else {
                    Text("贡献热力图")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            GitHubContributionHeatmap(
                days: snapshot.contributionDays,
                onHover: { hoveredContributionDay = $0 }
            )
            .frame(height: 72)

            Text("最近更新")
                .font(.system(size: 12, weight: .semibold))

            RecentRepositoryGrid(repositories: snapshot.repositories)
                .frame(height: 100, alignment: .top)
        }
    }
}
