import AppKit
import SwiftUI

struct RecentRepositoryGrid: View {
    let repositories: [GitHubRepository]

    var body: some View {
        if repositories.isEmpty {
            Text("暂无最近更新的公开仓库")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 7))
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2),
                spacing: 4
            ) {
                ForEach(repositories.recentlyPushed(limit: 6)) { repository in
                    RepositoryLinkCard(repository: repository)
                }
            }
        }
    }
}

private struct RepositoryLinkCard: View {
    let repository: GitHubRepository

    var body: some View {
        Button {
            guard GitHubRepositoryLinkPolicy.canOpen(repository.url) else { return }
            NSWorkspace.shared.open(repository.url)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 0) {
                    Text(repository.name)
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(relativeTime)
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 2)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .frame(height: 25)
            .contentShape(Rectangle())
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .help("打开 \(repository.name)")
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: repository.pushedAt, relativeTo: .now)
    }
}
