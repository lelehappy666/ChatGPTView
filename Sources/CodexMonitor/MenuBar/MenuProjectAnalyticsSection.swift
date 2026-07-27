import SwiftUI

struct ProjectAnalyticsBar: Identifiable, Equatable {
    let id: String
    let relativeHeight: Double
}

enum ProjectAnalyticsBarPlan {
    static func make(rows: [ProjectAnalyticsRow]) -> [ProjectAnalyticsBar] {
        guard let maximum = rows.map(\.tokens).max(), maximum > 0 else {
            return rows.map { ProjectAnalyticsBar(id: $0.id, relativeHeight: 0) }
        }
        return rows.map {
            ProjectAnalyticsBar(
                id: $0.id,
                relativeHeight: Double($0.tokens) / Double(maximum)
            )
        }
    }
}

struct MenuDailyTokenBar: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let tokens: Int
    let relativeHeight: Double
}

enum MenuDailyTokenBarPlan {
    static func make(
        days: [UsageDay],
        calendar: Calendar = .current,
        today: Date = .now
    ) -> [MenuDailyTokenBar] {
        let end = calendar.startOfDay(for: today)
        let start = calendar.date(byAdding: .day, value: -6, to: end) ?? end
        let indexed = Dictionary(
            uniqueKeysWithValues: days.map {
                (calendar.startOfDay(for: $0.date), $0.tokens)
            }
        )
        let selected = (0..<7).map { offset -> UsageDay in
            let date = calendar.date(
                byAdding: .day,
                value: offset,
                to: start
            ) ?? start
            return UsageDay(
                date: date,
                tokens: indexed[date] ?? 0,
                sessions: 0
            )
        }
        let maximum = max(1, selected.map(\.tokens).max() ?? 1)
        return selected.map {
            MenuDailyTokenBar(
                date: $0.date,
                tokens: $0.tokens,
                relativeHeight: Double($0.tokens) / Double(maximum)
            )
        }
    }
}

enum MenuChartAnimationPlan {
    static func initialProgress(
        targetProgress: Double,
        reduceMotion: Bool
    ) -> Double {
        reduceMotion ? normalized(targetProgress) : 0
    }

    static func normalized(_ progress: Double) -> Double {
        max(0, min(1, progress))
    }
}

struct MenuProjectAnalyticsSection: View {
    let analytics: ProjectAnalyticsSnapshot
    let dailyActivity: [UsageDay]
    let reduceMotion: Bool

    @State private var selectedRange: ProjectAnalyticsRange = .sevenDays
    @State private var hoveredProjectID: String?

    private var period: ProjectAnalyticsPeriodSnapshot {
        analytics.period(for: selectedRange)
    }

    private var bars: [MenuDailyTokenBar] {
        MenuDailyTokenBarPlan.make(days: dailyActivity)
    }

    private var hoveredRow: ProjectAnalyticsRow? {
        period.rows.first { $0.id == hoveredProjectID }
    }

    var body: some View {
        MenuDashboardSectionCard {
            VStack(alignment: .leading, spacing: 5) {
                MenuDashboardSectionHeader(
                    title: "项目分析",
                    subtitle: selectedRange.subtitle
                ) {
                    rangeSelector
                }

                HStack(alignment: .top, spacing: 12) {
                    tokenChart
                        .frame(maxWidth: .infinity)

                    Divider()

                    ranking
                        .frame(width: 168)
                }

                Text(hoverDetailText)
                    .font(.system(size: 6.8))
                    .foregroundStyle(hoveredRow == nil ? .secondary : Color.white.opacity(0.86))
                    .lineLimit(1)
            }
        }
        .onChange(of: selectedRange) {
            hoveredProjectID = nil
        }
    }

    private var rangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(ProjectAnalyticsRange.allCases, id: \.self) { range in
                Button {
                    select(range)
                } label: {
                    Text(range.title)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(selectedRange == range ? Color.white : Color.secondary)
                        .frame(width: 42, height: 20)
                        .contentShape(Rectangle())
                        .background(
                            selectedRange == range
                                ? MenuDashboardVisual.accent.opacity(0.42)
                                : Color.clear
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedRange == range ? .isSelected : [])
            }
        }
        .background(Color.white.opacity(0.05), in: Capsule())
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.7))
    }

    private var tokenChart: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("最近 7 天")
                Spacer()
                MenuRollingNumberText(
                    value: Double(bars.reduce(0) { $0 + $1.tokens }),
                    format: .tokens
                )
            }
            .font(.system(size: 7.5))
            .foregroundStyle(.secondary)

            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    VStack {
                        Divider()
                        Spacer()
                        Divider()
                        Spacer()
                        Divider()
                    }
                    .opacity(0.35)

                    HStack(alignment: .bottom, spacing: 7) {
                        ForEach(bars) { bar in
                            VStack(spacing: 2) {
                                Spacer(minLength: 0)
                                MenuAnimatedTokenBar(
                                    targetProgress: bar.relativeHeight,
                                    availableHeight: proxy.size.height - 12,
                                    helpText: "\(weekday(bar.date)) · \(MetricFormatter.tokens(bar.tokens)) Token"
                                )
                                Text(weekday(bar.date))
                                    .font(.system(size: 6.5))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .frame(height: 57)
        }
    }

    private var ranking: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("项目")
                Spacer()
                Text("Token 总数")
            }
            .font(.system(size: 7.5, weight: .medium))
            .foregroundStyle(.secondary)

            Divider()

            ForEach(period.rows.prefix(3)) { row in
                HStack(spacing: 5) {
                    Circle()
                        .fill(MenuDashboardVisual.accent)
                        .frame(width: 5, height: 5)
                    Text(row.name)
                        .font(.system(size: 8.5, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 4)
                    MenuRollingNumberText(
                        value: Double(row.tokens),
                        format: .tokens
                    )
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                }
                .padding(.horizontal, 5)
                .frame(height: 18)
                .contentShape(Rectangle())
                .background(
                    hoveredProjectID == row.id
                        ? MenuDashboardVisual.accent.opacity(0.16)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 4)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            hoveredProjectID == row.id
                                ? MenuDashboardVisual.accent.opacity(0.7)
                                : Color.clear,
                            lineWidth: 0.7
                        )
                }
                .onHover { hovering in
                    if hovering {
                        hoveredProjectID = row.id
                    } else if hoveredProjectID == row.id {
                        hoveredProjectID = nil
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(row.name)
                .accessibilityValue(rowAccessibilityValue(row))
            }
        }
    }

    private var hoverDetailText: String {
        guard let row = hoveredRow else {
            return "将鼠标移到排名项目中，查看会话与活跃天数"
        }
        return "\(row.name) · \(row.sessions) 次会话 · \(row.activeDays) 个活跃日"
    }

    private func select(_ range: ProjectAnalyticsRange) {
        guard selectedRange != range else { return }
        if reduceMotion {
            selectedRange = range
        } else {
            withAnimation(.snappy(duration: 0.18)) {
                selectedRange = range
            }
        }
    }

    private func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func rowAccessibilityValue(_ row: ProjectAnalyticsRow) -> String {
        "\(MetricFormatter.tokens(row.tokens)) Token，\(row.sessions) 次会话，\(row.activeDays) 个活跃日"
    }
}

private struct MenuAnimatedTokenBar: View {
    let targetProgress: Double
    let availableHeight: CGFloat
    let helpText: String

    @EnvironmentObject private var animationContext: MenuNumberAnimationContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedProgress: Double
    @State private var animationTask: Task<Void, Never>?

    init(
        targetProgress: Double,
        availableHeight: CGFloat,
        helpText: String
    ) {
        self.targetProgress = targetProgress
        self.availableHeight = availableHeight
        self.helpText = helpText
        _displayedProgress = State(initialValue: targetProgress)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(
                LinearGradient(
                    colors: [
                        MenuDashboardVisual.accent.opacity(0.65),
                        MenuDashboardVisual.accent
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(
                height: max(
                    3,
                    availableHeight * displayedProgress
                )
            )
            .help(helpText)
            .onAppear(perform: replayFromZero)
            .onChange(of: animationContext.cycle) {
                replayFromZero()
            }
            .onChange(of: targetProgress) {
                animateToTarget()
            }
            .onChange(of: reduceMotion) {
                if reduceMotion {
                    setWithoutAnimation(normalizedTarget)
                } else {
                    replayFromZero()
                }
            }
            .onDisappear {
                animationTask?.cancel()
                animationTask = nil
            }
    }

    private var normalizedTarget: Double {
        MenuChartAnimationPlan.normalized(targetProgress)
    }

    private func replayFromZero() {
        animationTask?.cancel()
        let initialProgress = MenuChartAnimationPlan.initialProgress(
            targetProgress: targetProgress,
            reduceMotion: reduceMotion
        )
        setWithoutAnimation(initialProgress)

        guard initialProgress != normalizedTarget else {
            animationTask = nil
            return
        }

        animationTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            withAnimation(
                .easeOut(duration: MenuAnimationTiming.chartDuration)
            ) {
                displayedProgress = normalizedTarget
            }
        }
    }

    private func animateToTarget() {
        animationTask?.cancel()
        animationTask = nil
        guard !reduceMotion else {
            setWithoutAnimation(normalizedTarget)
            return
        }
        withAnimation(
            .easeOut(duration: MenuAnimationTiming.chartDuration)
        ) {
            displayedProgress = normalizedTarget
        }
    }

    private func setWithoutAnimation(_ progress: Double) {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            displayedProgress = progress
        }
    }
}

private extension ProjectAnalyticsRange {
    var title: String {
        switch self {
        case .sevenDays: "7 天"
        case .thirtyDays: "30 天"
        case .all: "全部"
        }
    }

    var subtitle: String {
        switch self {
        case .sevenDays: "最近 7 天"
        case .thirtyDays: "最近 30 天"
        case .all: "全部历史"
        }
    }
}
