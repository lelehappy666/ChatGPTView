import SwiftUI

struct ProjectAnalyticsBar: Identifiable, Equatable {
    let id: String
    let relativeHeight: Double
}

enum ProjectAnalyticsBarPlan {
    static func make(rows: [ProjectAnalyticsRow]) -> [ProjectAnalyticsBar] {
        guard let maximumTokens = rows.map(\.tokens).max(), maximumTokens > 0 else {
            return rows.map { ProjectAnalyticsBar(id: $0.id, relativeHeight: 0) }
        }

        return rows.map { row in
            ProjectAnalyticsBar(
                id: row.id,
                relativeHeight: max(0, Double(row.tokens) / Double(maximumTokens))
            )
        }
    }
}

struct MenuProjectAnalyticsSection: View {
    let analytics: ProjectAnalyticsSnapshot
    let reduceMotion: Bool

    @State private var selectedRange: ProjectAnalyticsRange = .sevenDays
    @State private var hoveredProjectID: String?

    init(analytics: ProjectAnalyticsSnapshot, reduceMotion: Bool) {
        self.analytics = analytics
        self.reduceMotion = reduceMotion
    }

    private var period: ProjectAnalyticsPeriodSnapshot {
        analytics.period(for: selectedRange)
    }

    private var bars: [ProjectAnalyticsBar] {
        ProjectAnalyticsBarPlan.make(rows: period.rows)
    }

    private var hoveredRow: ProjectAnalyticsRow? {
        period.rows.first { $0.id == hoveredProjectID }
    }

    var body: some View {
        MenuDashboardSectionCard {
            VStack(alignment: .leading, spacing: 16) {
                MenuDashboardSectionHeader(
                    title: "项目分析",
                    subtitle: "按项目查看 Token 与会话"
                ) {
                    rangeSelector
                }

                if period.rows.isEmpty {
                    emptyState
                } else {
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Token 分布")
                                Spacer()
                                Text("共 \(MetricFormatter.tokens(period.totalTokens)) Token")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)

                            chart
                                .frame(height: 118)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        ranking
                            .frame(width: 230, alignment: .topLeading)
                    }

                    Text(hoverDetailText)
                        .font(.system(size: 10, weight: hoveredRow == nil ? .regular : .medium))
                        .foregroundStyle(hoveredRow == nil ? .secondary : Color.white.opacity(0.82))
                        .lineLimit(1)
                }
            }
        }
        .onChange(of: selectedRange) {
            hoveredProjectID = nil
        }
    }

    private var rangeSelector: some View {
        HStack(spacing: 3) {
            ForEach(ProjectAnalyticsRange.allCases, id: \.self) { range in
                Button {
                    select(range)
                } label: {
                    Text(range.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(selectedRange == range ? Color.black : Color.secondary)
                        .frame(minWidth: 58, minHeight: 28)
                        .contentShape(Rectangle())
                        .background(
                            selectedRange == range ? MenuDashboardVisual.accent : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看\(range.title)项目数据")
                .accessibilityAddTraits(selectedRange == range ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.055), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
        )
    }

    private var chart: some View {
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(bars) { bar in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            hoveredProjectID == bar.id
                                ? Color.white
                                : MenuDashboardVisual.accent
                        )
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 4,
                            maxHeight: proxy.size.height * bar.relativeHeight,
                            alignment: .bottom
                        )
                        .contentShape(Rectangle())
                        .onHover { isHovered in
                            if isHovered {
                                hoveredProjectID = bar.id
                            } else if hoveredProjectID == bar.id {
                                hoveredProjectID = nil
                            }
                        }
                        .animation(
                            reduceMotion ? nil : .snappy(duration: 0.18),
                            value: bar.relativeHeight
                        )
                        .accessibilityLabel(projectName(for: bar.id))
                        .accessibilityValue(projectAccessibilityValue(for: bar.id))
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var ranking: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Token 排名")
                Spacer()
                Text("前五")
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)

            ForEach(period.rows.prefix(5)) { row in
                HStack(spacing: 8) {
                    Text(row.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 8)
                    Text(MetricFormatter.tokens(row.tokens))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                    Text("\(Int((row.share * 100).rounded()))%")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(MenuDashboardVisual.accent)
                        .frame(width: 34, alignment: .trailing)
                }
                .contentShape(Rectangle())
                .onHover { isHovered in
                    if isHovered {
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

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .foregroundStyle(MenuDashboardVisual.accent)
            Text("这个时间范围还没有项目数据")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 118)
    }

    private var hoverDetailText: String {
        guard let row = hoveredRow else {
            return "将鼠标移到柱状图或项目上，查看会话与活跃天数"
        }
        let average = row.sessions > 0 ? row.tokens / row.sessions : 0
        return "\(row.name) · \(row.sessions) 次会话 · \(row.activeDays) 个活跃日 · 平均 \(MetricFormatter.tokens(average)) / 会话"
    }

    private func select(_ range: ProjectAnalyticsRange) {
        hoveredProjectID = nil
        guard selectedRange != range else { return }
        if reduceMotion {
            selectedRange = range
        } else {
            withAnimation(.snappy(duration: 0.18)) {
                selectedRange = range
            }
        }
    }

    private func projectName(for id: String) -> String {
        period.rows.first { $0.id == id }?.name ?? "项目"
    }

    private func projectAccessibilityValue(for id: String) -> String {
        guard let row = period.rows.first(where: { $0.id == id }) else { return "" }
        return rowAccessibilityValue(row)
    }

    private func rowAccessibilityValue(_ row: ProjectAnalyticsRow) -> String {
        let percent = Int((row.share * 100).rounded())
        return "\(MetricFormatter.tokens(row.tokens)) Token，\(percent)% ，\(row.sessions) 次会话，\(row.activeDays) 个活跃日"
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
}
