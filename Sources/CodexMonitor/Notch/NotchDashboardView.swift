import SwiftUI

struct NotchDashboardView: View {
    let snapshot: MonitorSnapshot
    let reduceMotion: Bool

    @State private var page = 0
    @State private var transitionForward = true
    @State private var githubLoadTask: Task<Void, Never>?
    @StateObject private var githubStore = GitHubActivityStore()

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: NotchLayout.contentTop)

            ZStack {
                currentPage
                    .id(page)
                    .transition(reduceMotion ? .identity : pageTransition)
            }
            .frame(width: NotchLayout.size.width, height: NotchLayout.pageContentHeight)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 12).onEnded { value in
                    navigate(
                        to: PageNavigation.target(
                            from: page,
                            delta: value.translation.width
                        )
                    )
                }
            )
            .background(WheelPagingCapture(page: pageBinding))

            HStack(spacing: 6) {
                ForEach(0..<NotchLayout.pageCount, id: \.self) { index in
                    Button {
                        navigate(to: index)
                    } label: {
                        Capsule()
                            .fill(index == page ? Color(red: 0.66, green: 0.60, blue: 0.94) : Color.white.opacity(0.20))
                            .frame(width: index == page ? 16 : 5, height: 5)
                    }
                    .buttonStyle(.plain)
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
        .onAppear {
            githubStore.primeFromCache()
        }
        .onChange(of: page) { _, newPage in
            githubLoadTask?.cancel()
            guard newPage == NotchLayout.pageCount - 1 else { return }
            githubLoadTask = Task {
                let delay = GitHubPageLoadPolicy.delayMilliseconds(
                    reduceMotion: reduceMotion
                )
                if delay > 0 {
                    try? await Task.sleep(for: .milliseconds(delay))
                }
                guard !Task.isCancelled else { return }
                await githubStore.loadIfNeeded()
            }
        }
        .onDisappear {
            githubLoadTask?.cancel()
        }
    }

    @ViewBuilder
    private var currentPage: some View {
        switch page {
        case 0:
            WeeklyQuotaPage(snapshot: snapshot)
        case 1:
            DailyActivityPage(snapshot: snapshot)
        case 2:
            ProjectAnalyticsPage(
                analytics: snapshot.projectAnalytics,
                reduceMotion: reduceMotion
            )
        case 3:
            StatisticsPage(snapshot: snapshot)
        default:
            GitHubActivityPage(store: githubStore)
        }
    }

    private var pageBinding: Binding<Int> {
        Binding(
            get: { page },
            set: { navigate(to: $0) }
        )
    }

    private var pageTransition: AnyTransition {
        let insertion: Edge = transitionForward ? .trailing : .leading
        let removal: Edge = transitionForward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertion).combined(with: .opacity),
            removal: .move(edge: removal).combined(with: .opacity)
        )
    }

    private func navigate(to target: Int) {
        guard target != page else { return }
        transitionForward = target > page
        if reduceMotion {
            page = target
        } else {
            withAnimation(.snappy(duration: 0.22)) {
                page = target
            }
        }
    }
}
