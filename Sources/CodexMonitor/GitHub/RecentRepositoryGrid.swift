import AppKit
import SwiftUI

enum RepositoryGridDensity: Equatable {
    case standard
    case compact
    case reference
}

enum RepositoryLeadingIcon: Equatable {
    case repository
    case github

    static func make(density: RepositoryGridDensity) -> Self {
        density == .reference ? .github : .repository
    }
}

struct RepositoryGridMetrics: Equatable {
    let columnCount: Int
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
                columnCount: 2,
                rowCount: 3,
                rowHeight: 30,
                rowSpacing: 4,
                columnSpacing: 6
            )
        case .compact:
            Self(
                columnCount: 2,
                rowCount: 3,
                rowHeight: 22,
                rowSpacing: 2,
                columnSpacing: 4
            )
        case .reference:
            Self(
                columnCount: 2,
                rowCount: 3,
                rowHeight: 25,
                rowSpacing: 3,
                columnSpacing: 8
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
                    count: metrics.columnCount
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
                leadingIcon

                VStack(alignment: .leading, spacing: 0) {
                    Text(repository.name)
                        .font(
                            .system(
                                size: titleSize,
                                weight: .semibold
                            )
                        )
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(relativeTime)
                        .font(.system(size: subtitleSize))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 2)
                Image(systemName: "arrow.up.right")
                    .font(
                        .system(
                            size: subtitleSize,
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

    @ViewBuilder
    private var leadingIcon: some View {
        switch RepositoryLeadingIcon.make(density: density) {
        case .repository:
            Image(systemName: "book.closed")
                .font(.system(size: iconSize))
                .foregroundStyle(.secondary)
                .frame(width: 14, height: 14)
        case .github:
            ZStack {
                Circle()
                    .fill(Color.white)
                Image(systemName: "cat.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.black)
            }
            .frame(width: 14, height: 14)
            .accessibilityHidden(true)
        }
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: repository.pushedAt, relativeTo: .now)
    }

    private var iconSize: CGFloat {
        switch density {
        case .compact: 9
        case .standard: 11
        case .reference: 10
        }
    }

    private var titleSize: CGFloat {
        switch density {
        case .compact: 9
        case .standard: 10
        case .reference: 8.5
        }
    }

    private var subtitleSize: CGFloat {
        switch density {
        case .compact: 7
        case .standard: 8
        case .reference: 7
        }
    }
}
