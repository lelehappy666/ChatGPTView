import SwiftUI

struct ProjectAnalyticsPage: View {
    let analytics: ProjectAnalyticsSnapshot
    let reduceMotion: Bool

    @State private var selectedRange: ProjectAnalyticsRange = .sevenDays
    @State private var hoveredProjectID: String?
    @FocusState private var focusedProjectID: String?

    private var period: ProjectAnalyticsPeriodSnapshot {
        analytics.period(for: selectedRange)
    }

    private var detailRow: ProjectAnalyticsRow? {
        let selectedID = hoveredProjectID ?? focusedProjectID
        return period.rows.first { $0.id == selectedID }
    }

    private var maximumTokens: Int {
        max(1, period.rows.map(\.tokens).max() ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header

            HStack(spacing: 6) {
                ProjectSummaryMetric(
                    title: "活跃项目",
                    value: period.activeProjects.formatted()
                )
                ProjectSummaryMetric(
                    title: "项目 Token",
                    value: MetricFormatter.tokens(period.totalTokens)
                )
                ProjectSummaryMetric(
                    title: "项目会话",
                    value: "\(period.totalSessions) 次"
                )
            }
            .frame(height: 34)

            HStack {
                Text("Token 排名")
                    .font(.system(size: 9, weight: .semibold))
                Spacer()
                Text("悬停查看项目明细")
                    .font(.system(size: 7))
                    .foregroundStyle(.secondary)
            }
            .frame(height: 12)

            if period.rows.isEmpty {
                DashboardCard(padding: 10) {
                    VStack(spacing: 5) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color(red: 0.65, green: 0.57, blue: 0.94))
                        Text("这个时间范围还没有项目数据")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 118)
            } else {
                VStack(spacing: 2) {
                    ForEach(period.rows) { row in
                        ProjectRankingRow(
                            row: row,
                            maximumTokens: maximumTokens,
                            highlighted: row.id == (hoveredProjectID ?? focusedProjectID),
                            reduceMotion: reduceMotion
                        )
                        .frame(height: 18)
                        .contentShape(Rectangle())
                        .focusable()
                        .focused($focusedProjectID, equals: row.id)
                        .onHover { isHovered in
                            if isHovered {
                                hoveredProjectID = row.id
                            } else if hoveredProjectID == row.id {
                                hoveredProjectID = nil
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(row.name)
                        .accessibilityValue(accessibilityValue(for: row))
                    }
                }
                .frame(height: 118, alignment: .top)
            }

            Text(detailText)
                .font(.system(size: 7.5, weight: detailRow == nil ? .regular : .medium))
                .foregroundStyle(detailRow == nil ? Color.secondary : Color.white.opacity(0.78))
                .lineLimit(1)
                .frame(height: 11)
        }
        .padding(.horizontal, 22)
        .frame(
            width: NotchLayout.size.width,
            height: NotchLayout.pageContentHeight,
            alignment: .top
        )
        .onChange(of: selectedRange) {
            hoveredProjectID = nil
            focusedProjectID = nil
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("项目分析")
                    .font(.system(size: 14, weight: .semibold))
                Text("按项目查看 Token 与会话")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            HStack(spacing: 2) {
                ForEach(ProjectAnalyticsRange.allCases, id: \.self) { range in
                    Button {
                        if reduceMotion {
                            selectedRange = range
                        } else {
                            withAnimation(.snappy(duration: 0.18)) {
                                selectedRange = range
                            }
                        }
                    } label: {
                        Text(range.title)
                            .font(.system(size: 7.5, weight: .semibold))
                            .foregroundStyle(selectedRange == range ? Color.white : Color.secondary)
                            .frame(width: 34, height: 19)
                            .contentShape(Rectangle())
                            .background(
                                selectedRange == range
                                    ? Color(red: 0.61, green: 0.53, blue: 0.91)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("查看\(range.title)项目数据")
                    .accessibilityAddTraits(selectedRange == range ? .isSelected : [])
                }
            }
            .padding(2)
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
            )
        }
        .frame(height: 30)
    }

    private var detailText: String {
        guard let row = detailRow else {
            return "将鼠标移到项目上，查看会话数、活跃天数和单次平均 Token"
        }
        let average = row.sessions > 0 ? row.tokens / row.sessions : 0
        return "\(row.name) · \(row.sessions) 次会话 · \(row.activeDays) 个活跃日 · 平均 \(MetricFormatter.tokens(average))/会话"
    }

    private func accessibilityValue(for row: ProjectAnalyticsRow) -> String {
        let percent = Int((row.share * 100).rounded())
        return "\(MetricFormatter.tokens(row.tokens)) Token，\(percent)%，\(row.sessions) 次会话，\(row.activeDays) 个活跃日"
    }
}

private struct ProjectSummaryMetric: View {
    let title: String
    let value: String

    var body: some View {
        DashboardCard(padding: 7) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 7))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
        }
    }
}

private struct ProjectRankingRow: View {
    let row: ProjectAnalyticsRow
    let maximumTokens: Int
    let highlighted: Bool
    let reduceMotion: Bool

    private var relativeWidth: CGFloat {
        max(0.025, CGFloat(row.tokens) / CGFloat(maximumTokens))
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(row.name)
                .font(.system(size: 8, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 94, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.075))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.47, green: 0.39, blue: 0.76),
                                    Color(red: 0.69, green: 0.59, blue: 0.96)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * relativeWidth)
                        .animation(
                            reduceMotion ? nil : .snappy(duration: 0.2),
                            value: relativeWidth
                        )
                }
            }
            .frame(height: 5)

            Text(MetricFormatter.tokens(row.tokens))
                .font(.system(size: 7.5, weight: .medium, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.64)
                .frame(width: 48, alignment: .trailing)

            Text("\(Int((row.share * 100).rounded()))%")
                .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.70, green: 0.63, blue: 0.98))
                .frame(width: 25, alignment: .trailing)
        }
        .padding(.horizontal, 7)
        .background(
            highlighted ? Color(red: 0.42, green: 0.34, blue: 0.66).opacity(0.25) : Color.white.opacity(0.025),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    highlighted
                        ? Color(red: 0.67, green: 0.58, blue: 0.95).opacity(0.52)
                        : Color.white.opacity(0.07),
                    lineWidth: 0.7
                )
        )
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
