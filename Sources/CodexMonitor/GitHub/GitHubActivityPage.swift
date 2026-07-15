import AppKit
import SwiftUI

struct GitHubActivityPage: View {
    @ObservedObject var store: GitHubActivityStore

    var body: some View {
        ZStack {
            switch store.state {
            case .unbound(let message):
                GitHubUnboundBackdrop()
                GitHubAuthorizationCard(message: message) { token in
                    await store.bind(token: token)
                }
                .offset(y: 18)

            case .loading(let cached):
                if let cached {
                    GitHubActivityContent(
                        snapshot: cached,
                        statusMessage: "正在刷新",
                        onRefresh: store.refresh,
                        onDisconnect: store.disconnect
                    )
                } else {
                    GitHubUnboundBackdrop()
                    ProgressView()
                        .controlSize(.small)
                        .offset(y: 18)
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
                    GitHubUnboundBackdrop()
                    GitHubAuthorizationCard(message: message) { token in
                        await store.bind(token: token)
                    }
                    .offset(y: 18)
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
}

private struct GitHubUnboundBackdrop: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GitHubPageHeader(
                subtitle: "贡献与最近更新",
                trailing: { GitHubMarkView(size: 28) }
            )

            Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                let gridTop: CGFloat = 18
                let columns = 53
                let rows = 7
                let spacing: CGFloat = 1.25
                let cell = (size.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)

                for column in 0..<columns {
                    for row in 0..<rows {
                        let seed = (column * 17 + row * 11) % 9
                        let opacity = seed > 5 ? 0.12 : 0.055
                        let rect = CGRect(
                            x: CGFloat(column) * (cell + spacing),
                            y: gridTop + CGFloat(row) * (cell + spacing),
                            width: cell,
                            height: cell
                        )
                        context.fill(
                            Path(roundedRect: rect, cornerRadius: 1.4),
                            with: .color(Color.white.opacity(opacity))
                        )
                    }
                }

                let cardTop = gridTop + CGFloat(rows) * (cell + spacing) + 28
                let cardWidth = (size.width - 8) / 2
                for index in 0..<6 {
                    let column = index % 2
                    let row = index / 2
                    let rect = CGRect(
                        x: CGFloat(column) * (cardWidth + 8),
                        y: cardTop + CGFloat(row) * 40,
                        width: cardWidth,
                        height: 32
                    )
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 8),
                        with: .color(Color.white.opacity(0.04))
                    )
                }
            }
            .opacity(0.55)
        }
    }
}

private struct GitHubActivityContent: View {
    let snapshot: GitHubActivitySnapshot
    let statusMessage: String?
    let onRefresh: () async -> Void
    let onDisconnect: () -> Void

    @State private var hoveredContributionDay: GitHubContributionDay?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            GitHubPageHeader(
                subtitle: statusMessage ?? "最近 12 个月",
                subtitleColor: statusMessage == nil ? .secondary : Color.orange,
                trailing: {
                    Button {
                        Task { await onRefresh() }
                    } label: {
                        HStack(spacing: 6) {
                            Text(snapshot.username).lineLimit(1)
                            Circle()
                                .fill(Color(red: 0.31, green: 0.84, blue: 0.56))
                                .frame(width: 6, height: 6)
                        }
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(
                            Color.white.opacity(0.055),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("刷新 GitHub 数据；右键可解除绑定")
                    .contextMenu {
                        Button("解除绑定", role: .destructive, action: onDisconnect)
                    }
                }
            )

            HStack(alignment: .center) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(snapshot.totalContributions.formatted())
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.70, green: 0.63, blue: 0.98))
                    Text("次贡献")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let hoveredContributionDay {
                    Text(GitHubContributionTooltip.text(for: hoveredContributionDay))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    GitHubContributionLegend()
                }
            }
            .frame(height: 18)

            GitHubContributionHeatmap(
                days: snapshot.contributionDays,
                onHover: { hoveredContributionDay = $0 }
            )
                .frame(height: 42)

            Text("最近更新")
                .font(.system(size: 11, weight: .semibold))
                .padding(.top, 1)

            RecentRepositoryGrid(repositories: snapshot.repositories)
                .frame(height: 98, alignment: .top)
        }
    }
}

private struct GitHubPageHeader<Trailing: View>: View {
    let subtitle: String
    var subtitleColor: Color = .secondary
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("GitHub 活跃")
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(1)
            }
            Spacer()
            trailing()
        }
        .frame(height: 30)
    }
}

private struct GitHubContributionLegend: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("少")
            ForEach(0...4, id: \.self) { level in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color(level: level))
                    .frame(width: 8, height: 8)
            }
            Text("多")
        }
        .font(.system(size: 8))
        .foregroundStyle(.secondary)
    }

    private func color(level: Int) -> Color {
        switch level {
        case 1: return Color(red: 0.22, green: 0.21, blue: 0.27)
        case 2: return Color(red: 0.37, green: 0.33, blue: 0.50)
        case 3: return Color(red: 0.52, green: 0.45, blue: 0.73)
        case 4: return Color(red: 0.70, green: 0.63, blue: 0.98)
        default: return Color.white.opacity(0.10)
        }
    }
}

private struct GitHubMarkView: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "cat.fill")
            .font(.system(size: size * 0.50, weight: .bold))
            .foregroundStyle(Color.black)
            .frame(width: size, height: size)
            .background(Color.white, in: Circle())
    }
}

private struct GitHubAuthorizationCard: View {
    let message: String?
    let onBind: (String) async -> Void

    var body: some View {
        VStack(spacing: 10) {
            GitHubMarkView(size: 40)
                .overlay(
                    Circle()
                        .stroke(Color(red: 0.66, green: 0.58, blue: 0.95), lineWidth: 1)
                        .padding(-5)
                )

            Text(GitHubAuthorizationContent.title)
                .font(.system(size: 16, weight: .semibold))

            Text(message ?? GitHubAuthorizationContent.message)
                .font(.system(size: 9))
                .foregroundStyle(message == nil ? .secondary : Color.orange)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Button(GitHubAuthorizationContent.primaryAction, action: authorize)
                .buttonStyle(GitHubPrimaryButtonStyle())

            Label(GitHubAuthorizationContent.privacyNote, systemImage: "lock.fill")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .frame(width: 244, height: 170)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(red: 0.055, green: 0.055, blue: 0.070).opacity(0.98))
                LinearGradient(
                    colors: [Color.white.opacity(0.045), Color.clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .clipShape(RoundedRectangle(cornerRadius: 15))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.28), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
    }

    private func authorize() {
        let clipboard = NSPasteboard.general.string(forType: .string)
        switch GitHubAuthorizationAction.next(clipboard: clipboard) {
        case .bind(let token):
            Task { await onBind(token) }
        case .openTokenPage:
            guard let url = URL(
                string: "https://github.com/settings/tokens/new?description=Codex%20Monitor"
            ) else { return }
            NSWorkspace.shared.open(url)
        }
    }
}

private struct GitHubPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .foregroundStyle(Color.white)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.61, green: 0.52, blue: 0.94),
                        Color(red: 0.70, green: 0.62, blue: 0.96)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .opacity(configuration.isPressed ? 0.75 : 1),
                in: RoundedRectangle(cornerRadius: 8)
            )
    }
}
