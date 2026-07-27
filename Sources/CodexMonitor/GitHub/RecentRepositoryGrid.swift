import AppKit
import SwiftUI

enum RepositoryGridDensity: Equatable {
    case standard
    case compact
}

struct RepositoryGridMetrics: Equatable {
    let rowCount: Int
    let rowHeight: CGFloat
    let rowSpacing: CGFloat
    let columnSpacing: CGFloat

    var totalHeight: CGFloat {
        CGFloat(rowCount) * rowHeight
            + CGFloat(rowCount - 1) * rowSpacing
    }

    static func make(density: RepositoryGridDensity) -> Self {
        switch density {
        case .standard:
            Self(
                rowCount: 3,
                rowHeight: 30,
                rowSpacing: 4,
                columnSpacing: 6
            )
        case .compact:
            Self(
                rowCount: 3,
                rowHeight: 22,
                rowSpacing: 2,
                columnSpacing: 4
            )
        }
    }
}

struct RecentRepositoryGrid: View {
    let repositories: [GitHubRepository]
    let density: RepositoryGridDensity

    init(
        repositories: [GitHubRepository],
        density: RepositoryGridDensity = .standard
    ) {
        self.repositories = repositories
        self.density = density
    }

    private var metrics: RepositoryGridMetrics {
        .make(density: density)
    }

    var body: some View {
        if repositories.isEmpty {
            Text("暂无最近更新的公开仓库")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 7))
        } else {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(
                        .flexible(),
                        spacing: metrics.columnSpacing
                    ),
                    count: 2
                ),
                spacing: metrics.rowSpacing
            ) {
                ForEach(repositories.recentlyPushed(limit: 6)) { repository in
                    RepositoryLinkCard(
                        repository: repository,
                        density: density
                    )
                }
            }
        }
    }
}

private struct RepositoryLinkCard: View {
    let repository: GitHubRepository
    let density: RepositoryGridDensity

    private var metrics: RepositoryGridMetrics {
        .make(density: density)
    }

    var body: some View {
        Button {
            guard GitHubRepositoryLinkPolicy.canOpen(repository.url) else { return }
            NSWorkspace.shared.open(repository.url)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "book.closed")
                    .font(.system(size: density == .compact ? 9 : 11))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 0) {
                    Text(repository.name)
                        .font(
                            .system(
                                size: density == .compact ? 9 : 10,
                                weight: .semibold
                            )
                        )
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(relativeTime)
                        .font(.system(size: density == .compact ? 7 : 8))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 2)
                Image(systemName: "arrow.up.right")
                    .font(
                        .system(
                            size: density == .compact ? 7 : 8,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, density == .compact ? 6 : 8)
            .frame(height: metrics.rowHeight)
            .contentShape(Rectangle())
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
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
