import Combine
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var store: MonitorStore
    let onHoverChanged: (Bool) -> Void

    @State private var now = Date.now
    @StateObject private var ticker = ProjectTickerState()

    private let timer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 7) {
            OpenAIKnotMark()
                .frame(width: 14, height: 14)

            Text(weeklyText)
                .font(.system(size: 11, weight: .semibold))
                .fixedSize()

            if store.refreshState == .refreshing {
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: 10, height: 10)
            }

            if let project = ticker.currentProject {
                ProjectTickerView(
                    project: project,
                    totalCount: ticker.projects.count,
                    isPaused: $ticker.isPaused
                )
                .id(project.id + String(ticker.index))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(height: 22)
        .contentShape(Rectangle())
        .onHover(perform: onHoverChanged)
        .onReceive(timer) { now in
            self.now = now
            ticker.projects = store.snapshot.projects.visibleForMenu(at: now)
            withAnimation(.easeInOut(duration: 0.28)) {
                ticker.advance()
            }
        }
        .onReceive(store.$snapshot) { snapshot in
            ticker.projects = snapshot.projects.visibleForMenu()
        }
    }

    private var weeklyText: String {
        guard let remaining = QuotaFreshnessPolicy.displayState(
            for: store.snapshot.weeklyQuota,
            at: now
        ).remainingPercent else {
            return "Week —"
        }
        return "Week \(Int(remaining.rounded()))%"
    }
}

private struct ProjectTickerView: View {
    let project: ProjectActivity
    let totalCount: Int
    @Binding var isPaused: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(
                    width: project.state == .running ? 8 : 6,
                    height: project.state == .running ? 8 : 6
                )
                .shadow(color: statusColor.opacity(0.9), radius: project.state == .running ? 4 : 0)

            Text(project.name)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 104, alignment: .leading)

            Text(statusText)
                .font(.system(size: project.state == .running ? 9 : 8, weight: .bold))
                .foregroundStyle(
                    project.state == .running
                        ? Color.black.opacity(0.88)
                        : statusColor
                )
                .padding(.horizontal, project.state == .running ? 6 : 0)
                .frame(height: project.state == .running ? 17 : nil)
                .background {
                    if project.state == .running {
                        Capsule().fill(RGBToken.runningAccent.color)
                    }
                }
                .fixedSize()

            Divider().frame(height: 12).opacity(0.25)

            Text("\(totalCount) 项目")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .padding(.horizontal, 6)
        .frame(height: 22)
        .background(statusBackground, in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(statusBorder, lineWidth: project.state == .running ? 1 : 0)
        }
        .onHover { isPaused = $0 }
        .help("\(project.name) · \(statusText)")
    }

    private var statusText: String {
        switch project.state {
        case .running: return "进行中"
        case .completed: return "完成"
        case .failed: return "报错"
        }
    }

    private var statusColor: Color {
        switch project.state {
        case .running: return RGBToken.runningAccent.color
        case .completed: return Color(red: 0.38, green: 0.87, blue: 0.69)
        case .failed: return Color(red: 1, green: 0.42, blue: 0.44)
        }
    }

    private var statusBackground: Color {
        Color.primary.opacity(0.07)
    }

    private var statusBorder: Color {
        .clear
    }
}

struct OpenAIKnotMark: View {
    var color: Color = .primary

    var body: some View {
        ZStack {
            ForEach([0.0, 60.0, 120.0], id: \.self) { angle in
                Capsule()
                    .stroke(color, lineWidth: 1.25)
                    .frame(width: 6.5, height: 12.5)
                    .rotationEffect(.degrees(angle))
            }
        }
        .accessibilityHidden(true)
    }
}
