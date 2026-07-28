import AppKit
import Foundation
import SwiftUI

private enum PosterConstants {
    static let canvasSize = CGSize(width: 1_920, height: 1_080)
    static let outputScale: CGFloat = 2
    static let panelWidth: CGFloat = 520
    static let panelScale = panelWidth / NotchLayout.size.width
    static let panelHeight = NotchLayout.size.height * panelScale
    static let horizontalSpacing: CGFloat = 28
    static let verticalSpacing: CGFloat = 24
}

private enum PosterRenderError: LocalizedError {
    case missingArgument(String)
    case unreadableBackground(URL)
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .missingArgument(let name):
            return "缺少命令行参数：\(name)"
        case .unreadableBackground(let url):
            return "无法读取背景图片：\(url.path)"
        case .imageEncodingFailed:
            return "无法编码最终 PNG"
        }
    }
}

private struct PosterArguments {
    let backgroundURL: URL
    let outputURL: URL

    init(arguments: [String]) throws {
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag),
                  arguments.indices.contains(index + 1) else {
                return nil
            }
            return arguments[index + 1]
        }

        guard let background = value(after: "--background") else {
            throw PosterRenderError.missingArgument("--background")
        }
        guard let output = value(after: "--output") else {
            throw PosterRenderError.missingArgument("--output")
        }

        backgroundURL = URL(fileURLWithPath: background)
        outputURL = URL(fileURLWithPath: output)
    }
}

private enum PosterSnapshotLoader {
    static func loadMonitorSnapshot() async throws -> MonitorSnapshot {
        let sessions = try await SessionScanner.scan(root: AppPaths.sessionsRoot())
        let analytics = await ProjectAnalyticsIndex().update(sessions: sessions)
        return UsageAggregator.makeSnapshot(
            sessions: sessions,
            projectAnalytics: analytics
        )
    }

    @MainActor
    static func loadGitHubSnapshot() -> GitHubActivitySnapshot? {
        guard let defaults = UserDefaults(
            suiteName: "com.dafeng.codexmonitor"
        ) else {
            return nil
        }
        return UserDefaultsGitHubActivityCache(defaults: defaults).load()
    }
}

private final class PosterGitHubLoader: GitHubActivityLoading, @unchecked Sendable {
    let snapshot: GitHubActivitySnapshot

    init(snapshot: GitHubActivitySnapshot) {
        self.snapshot = snapshot
    }

    func fetchActivity(token: String) async throws -> GitHubActivitySnapshot {
        snapshot
    }
}

private final class PosterGitHubCredentials:
    GitHubCredentialStoring,
    @unchecked Sendable
{
    func readToken() throws -> String? { "poster-cached-token" }
    func saveToken(_ token: String) throws {}
    func deleteToken() throws {}
}

@MainActor
private final class PosterGitHubCache: GitHubActivityCaching {
    private var snapshot: GitHubActivitySnapshot?

    init(snapshot: GitHubActivitySnapshot?) {
        self.snapshot = snapshot
    }

    func load() -> GitHubActivitySnapshot? { snapshot }
    func save(_ snapshot: GitHubActivitySnapshot) { self.snapshot = snapshot }
    func clear() { snapshot = nil }
}

@MainActor
private func makeGitHubStore(
    snapshot: GitHubActivitySnapshot?
) async -> GitHubActivityStore {
    guard let snapshot else {
        return GitHubActivityStore(
            cache: PosterGitHubCache(snapshot: nil)
        )
    }

    let store = GitHubActivityStore(
        loader: PosterGitHubLoader(snapshot: snapshot),
        credentials: PosterGitHubCredentials(),
        cache: PosterGitHubCache(snapshot: snapshot)
    )
    await store.loadIfNeeded()
    return store
}

private struct PosterNotchFrame<Content: View>: View {
    let selectedPage: Int
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: NotchLayout.contentTop)

            content()
                .frame(
                    width: NotchLayout.size.width,
                    height: NotchLayout.pageContentHeight
                )
                .clipped()

            HStack(spacing: 6) {
                ForEach(0..<NotchLayout.pageCount, id: \.self) { index in
                    Capsule()
                        .fill(
                            index == selectedPage
                                ? Color(red: 0.66, green: 0.60, blue: 0.94)
                                : Color.white.opacity(0.20)
                        )
                        .frame(
                            width: index == selectedPage ? 16 : 5,
                            height: 5
                        )
                }
            }
            .frame(height: NotchLayout.pagerHeight)
        }
        .foregroundStyle(Color.white)
        .environment(\.colorScheme, .dark)
        .frame(width: NotchLayout.size.width, height: NotchLayout.size.height)
        .background(Color.black)
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 24
            )
        )
    }
}

private struct ScaledNotchPanel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .scaleEffect(PosterConstants.panelScale)
            .frame(
                width: PosterConstants.panelWidth,
                height: PosterConstants.panelHeight
            )
            .shadow(color: .black.opacity(0.62), radius: 20, y: 12)
            .overlay {
                UnevenRoundedRectangle(
                    bottomLeadingRadius: 30,
                    bottomTrailingRadius: 30
                )
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
    }
}

private struct PosterBrandHeader: View {
    let snapshot: MonitorSnapshot
    let appIcon: NSImage

    private var remainingText: String {
        guard let remaining = snapshot.weeklyQuota.remainingPercent else {
            return "Week —"
        }
        return "Week \(Int(remaining.rounded()))%"
    }

    private var latestProject: ProjectActivity? {
        snapshot.projects.sortedForMenu.first
    }

    var body: some View {
        HStack(spacing: 18) {
            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text("Codex Monitor")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)
                Text("macOS 刘海数据面板")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.54))
            }

            Spacer()

            HStack(spacing: 10) {
                OpenAIKnotMark(color: Color(red: 0.70, green: 0.63, blue: 0.98))
                    .frame(width: 21, height: 21)
                Text(remainingText)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)

                if let project = latestProject {
                    Rectangle()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 1, height: 22)

                    Circle()
                        .fill(statusColor(project.state))
                        .frame(width: 8, height: 8)

                    Text(project.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.86))
                        .lineLimit(1)
                        .frame(maxWidth: 180)
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 46)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.20, green: 0.18, blue: 0.31).opacity(0.94),
                        Color.black.opacity(0.88)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            }
        }
        .frame(maxWidth: 1_616)
    }

    private func statusColor(_ state: ProjectRunState) -> Color {
        switch state {
        case .running:
            return RGBToken.runningAccent.color
        case .completed:
            return Color(red: 0.38, green: 0.87, blue: 0.69)
        case .failed:
            return Color(red: 1, green: 0.42, blue: 0.44)
        }
    }
}

private struct NotchPosterView: View {
    let background: NSImage
    let appIcon: NSImage
    let snapshot: MonitorSnapshot
    @ObservedObject var githubStore: GitHubActivityStore

    var body: some View {
        ZStack {
            Image(nsImage: background)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(
                    width: PosterConstants.canvasSize.width,
                    height: PosterConstants.canvasSize.height
                )
                .clipped()

            Color.black.opacity(0.14)

            VStack(spacing: PosterConstants.verticalSpacing) {
                PosterBrandHeader(snapshot: snapshot, appIcon: appIcon)
                    .frame(height: 90)

                HStack(spacing: PosterConstants.horizontalSpacing) {
                    panel(page: 0) {
                        WeeklyQuotaPage(
                            snapshot: snapshot,
                            refreshState: .updated,
                            onRefresh: {}
                        )
                    }

                    panel(page: 1) {
                        DailyActivityPage(snapshot: snapshot)
                    }
                }

                HStack(spacing: PosterConstants.horizontalSpacing) {
                    panel(page: 2) {
                        ProjectAnalyticsPage(
                            analytics: snapshot.projectAnalytics,
                            reduceMotion: true
                        )
                    }

                    panel(page: 3) {
                        StatisticsPage(snapshot: snapshot)
                    }

                    panel(page: 4) {
                        GitHubActivityPage(store: githubStore)
                    }
                }
            }
            .padding(.top, 24)
            .frame(
                width: PosterConstants.canvasSize.width,
                height: PosterConstants.canvasSize.height,
                alignment: .top
            )
        }
        .frame(
            width: PosterConstants.canvasSize.width,
            height: PosterConstants.canvasSize.height
        )
        .environment(\.colorScheme, .dark)
    }

    private func panel<Content: View>(
        page: Int,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ScaledNotchPanel {
            PosterNotchFrame(selectedPage: page, content: content)
        }
    }
}

@main
private struct GenerateNotchPoster {
    @MainActor
    static func main() async {
        do {
            let arguments = try PosterArguments(
                arguments: CommandLine.arguments
            )
            guard let background = NSImage(
                contentsOf: arguments.backgroundURL
            ) else {
                throw PosterRenderError.unreadableBackground(
                    arguments.backgroundURL
                )
            }
            guard let appIcon = NSImage(
                contentsOfFile: "Resources/AppIconPreview.png"
            ) else {
                throw PosterRenderError.unreadableBackground(
                    URL(fileURLWithPath: "Resources/AppIconPreview.png")
                )
            }

            let snapshot = try await PosterSnapshotLoader.loadMonitorSnapshot()
            let githubSnapshot = PosterSnapshotLoader.loadGitHubSnapshot()
            let githubStore = await makeGitHubStore(snapshot: githubSnapshot)

            let renderer = ImageRenderer(
                content: NotchPosterView(
                    background: background,
                    appIcon: appIcon,
                    snapshot: snapshot,
                    githubStore: githubStore
                )
            )
            renderer.proposedSize = ProposedViewSize(
                width: PosterConstants.canvasSize.width,
                height: PosterConstants.canvasSize.height
            )
            renderer.scale = PosterConstants.outputScale

            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(
                      using: .png,
                      properties: [:]
                  ) else {
                throw PosterRenderError.imageEncodingFailed
            }

            try FileManager.default.createDirectory(
                at: arguments.outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try png.write(to: arguments.outputURL, options: .atomic)
            print("已生成：\(arguments.outputURL.path)")
        } catch {
            let message = "生成失败：\(error.localizedDescription)\n"
            FileHandle.standardError.write(Data(message.utf8))
            exit(EXIT_FAILURE)
        }
    }
}
