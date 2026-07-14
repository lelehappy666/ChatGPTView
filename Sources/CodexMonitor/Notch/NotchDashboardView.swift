import SwiftUI

struct NotchDashboardView: View {
    let snapshot: MonitorSnapshot
    let reduceMotion: Bool

    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: NotchLayout.contentTop)

            HStack(spacing: 0) {
                WeeklyQuotaPage(snapshot: snapshot)
                DailyActivityPage(snapshot: snapshot)
                StatisticsPage(snapshot: snapshot)
            }
            .frame(width: NotchLayout.size.width * CGFloat(NotchLayout.pageCount), alignment: .leading)
            .offset(x: -CGFloat(page) * NotchLayout.size.width)
            .frame(width: NotchLayout.size.width, height: NotchLayout.pageContentHeight, alignment: .leading)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 12).onEnded { value in
                    if value.translation.width < -28 { page = min(page + 1, NotchLayout.pageCount - 1) }
                    if value.translation.width > 28 { page = max(page - 1, 0) }
                }
            )

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
        .frame(width: NotchLayout.size.width, height: NotchLayout.size.height)
        .background(Color.black)
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 24
            )
        )
        .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: page)
    }
}
