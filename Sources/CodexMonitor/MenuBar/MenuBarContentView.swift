import Combine
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var store: MonitorStore
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
            } else if !store.isLoading {
                Text("暂无项目")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 22)
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.28)) {
                ticker.advance()
            }
        }
        .onReceive(store.$snapshot) { snapshot in
            ticker.projects = snapshot.projects
        }
    }

    private var weeklyText: String {
        guard let remaining = store.snapshot.weeklyQuota.remainingPercent else {
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
                .frame(width: 6, height: 6)
                .shadow(color: statusColor.opacity(0.7), radius: project.state == .running ? 3 : 0)

            Text(project.name)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 104, alignment: .leading)

            Text(statusText)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(statusColor)
                .fixedSize()

            Divider().frame(height: 12).opacity(0.25)

            Text("\(totalCount) 项目")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .padding(.horizontal, 6)
        .frame(height: 22)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
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
        case .running: return Color(red: 0.44, green: 0.65, blue: 1)
        case .completed: return Color(red: 0.38, green: 0.87, blue: 0.69)
        case .failed: return Color(red: 1, green: 0.42, blue: 0.44)
        }
    }
}

private struct OpenAIKnotMark: View {
    var body: some View {
        ZStack {
            ForEach([0.0, 60.0, 120.0], id: \.self) { angle in
                Capsule()
                    .stroke(Color.primary, lineWidth: 1.25)
                    .frame(width: 6.5, height: 12.5)
                    .rotationEffect(.degrees(angle))
            }
        }
        .accessibilityLabel("ChatGPT")
    }
}
