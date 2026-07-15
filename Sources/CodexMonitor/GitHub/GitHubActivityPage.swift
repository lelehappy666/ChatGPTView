import AppKit
import SwiftUI

struct GitHubActivityPage: View {
    @ObservedObject var store: GitHubActivityStore

    var body: some View {
        ZStack {
            switch store.state {
            case .unbound(let message):
                GitHubActivityContent(
                    snapshot: placeholderSnapshot,
                    statusMessage: nil,
                    onRefresh: {},
                    onDisconnect: {}
                )
                .blur(radius: 2)
                .opacity(0.25)

                GitHubAuthorizationCard(message: message) { token in
                    await store.bind(token: token)
                }

            case .loading(let cached):
                GitHubActivityContent(
                    snapshot: cached ?? placeholderSnapshot,
                    statusMessage: cached == nil ? "正在连接" : "正在刷新",
                    onRefresh: store.refresh,
                    onDisconnect: store.disconnect
                )
                .opacity(cached == nil ? 0.40 : 1)
                if cached == nil {
                    ProgressView().controlSize(.small)
                }

            case .loaded(let snapshot):
                GitHubActivityContent(
                    snapshot: snapshot,
                    statusMessage: nil,
                    onRefresh: store.refresh,
                    onDisconnect: store.disconnect
                )

            case .failed(let message, let cached):
                if let cached {
                    GitHubActivityContent(
                        snapshot: cached,
                        statusMessage: message,
                        onRefresh: store.refresh,
                        onDisconnect: store.disconnect
                    )
                } else {
                    GitHubAuthorizationCard(message: message) { token in
                        await store.bind(token: token)
                    }
                }
            }
        }
        .padding(.horizontal, 22)
        .frame(
            width: NotchLayout.size.width,
            height: NotchLayout.pageContentHeight,
            alignment: .top
        )
    }

    private var placeholderSnapshot: GitHubActivitySnapshot {
        GitHubActivitySnapshot(
            username: "GitHub",
            totalContributions: 0,
            contributionDays: [],
            repositories: [],
            fetchedAt: .distantPast
        )
    }
}

private struct GitHubActivityContent: View {
    let snapshot: GitHubActivitySnapshot
    let statusMessage: String?
    let onRefresh: () async -> Void
    let onDisconnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("GitHub 活跃")
                        .font(.system(size: 14, weight: .semibold))
                    Text(statusMessage ?? "最近 12 个月")
                        .font(.system(size: 9))
                        .foregroundStyle(statusMessage == nil ? .secondary : Color.orange)
                        .lineLimit(1)
                }
                Spacer()
                Menu {
                    Button("刷新") {
                        Task { await onRefresh() }
                    }
                    Divider()
                    Button("解除绑定", role: .destructive, action: onDisconnect)
                } label: {
                    HStack(spacing: 5) {
                        Text(snapshot.username)
                            .lineLimit(1)
                        Circle()
                            .fill(Color(red: 0.31, green: 0.82, blue: 0.55))
                            .frame(width: 5, height: 5)
                    }
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 7)
                    .frame(height: 20)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(snapshot.totalContributions.formatted())
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.67, green: 0.60, blue: 0.94))
                    Text("次贡献")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 58, alignment: .leading)

                GitHubContributionHeatmap(days: snapshot.contributionDays)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 43)

            Text("最近更新")
                .font(.system(size: 10, weight: .semibold))

            RecentRepositoryGrid(repositories: snapshot.repositories)
                .frame(height: 83, alignment: .top)
        }
    }

}

private struct GitHubAuthorizationCard: View {
    let message: String?
    let onBind: (String) async -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text("GH")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .frame(width: 25, height: 25)
                .background(Color.white.opacity(0.10), in: Circle())
                .overlay(Circle().stroke(Color(red: 0.67, green: 0.60, blue: 0.94).opacity(0.7)))

            Text(GitHubAuthorizationContent.title)
                .font(.system(size: 13, weight: .semibold))
            Text(message ?? GitHubAuthorizationContent.message)
                .font(.system(size: 8))
                .foregroundStyle(message == nil ? .secondary : Color.orange)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            HStack(spacing: 6) {
                Button(GitHubAuthorizationContent.primaryAction) {
                    guard let url = URL(
                        string: "https://github.com/settings/tokens/new?description=Codex%20Monitor"
                    ) else { return }
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(GitHubPrimaryButtonStyle())

                Button("从剪贴板绑定") {
                    let token = NSPasteboard.general.string(forType: .string) ?? ""
                    Task { await onBind(token) }
                }
                .buttonStyle(GitHubSecondaryButtonStyle())
            }

            Text(GitHubAuthorizationContent.privacyNote)
                .font(.system(size: 7))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .frame(width: 292, height: 138)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.14))
        )
    }
}

private struct GitHubPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 12)
            .frame(height: 24)
            .background(
                Color(red: 0.67, green: 0.60, blue: 0.94)
                    .opacity(configuration.isPressed ? 0.72 : 1),
                in: RoundedRectangle(cornerRadius: 7)
            )
    }
}

private struct GitHubSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 9, weight: .medium))
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Color.white.opacity(configuration.isPressed ? 0.12 : 0.07), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.10)))
    }
}
