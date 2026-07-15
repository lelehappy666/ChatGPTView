import SwiftUI

struct NotchDashboardView: View {
    let snapshot: MonitorSnapshot
    let reduceMotion: Bool

    @State private var page = 0
    @StateObject private var githubStore = GitHubActivityStore()

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: NotchLayout.contentTop)

            HStack(spacing: 0) {
                WeeklyQuotaPage(snapshot: snapshot)
                DailyActivityPage(snapshot: snapshot)
                StatisticsPage(snapshot: snapshot)
                GitHubActivityPage(store: githubStore)
            }
            .frame(width: NotchLayout.size.width * CGFloat(NotchLayout.pageCount), alignment: .leading)
            .offset(x: -CGFloat(page) * NotchLayout.size.width)
            .frame(width: NotchLayout.size.width, height: NotchLayout.pageContentHeight, alignment: .leading)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 12).onEnded { value in
                    page = PageNavigation.target(from: page, delta: value.translation.width)
                }
            )
            .background(WheelPagingCapture(page: $page))

            HStack(spacing: 6) {
                ForEach(0..<NotchLayout.pageCount, id: \.self) { index in
                    Button {
                        page = index
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
        .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: page)
        .onChange(of: page) { _, newPage in
            guard newPage == NotchLayout.pageCount - 1 else { return }
            Task { await githubStore.loadIfNeeded() }
        }
    }
}
