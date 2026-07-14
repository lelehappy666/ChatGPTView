import Foundation

enum NotchLayout {
    static let size = CGSize(width: 328, height: 198)
    static let contentTop: CGFloat = 39
    static let pagerHeight: CGFloat = 30
    static let pageContentHeight: CGFloat = 129
    static let statisticsBottomSafeArea: CGFloat = 12
    static let pageCount = 3
}

enum MetricFormatter {
    static func tokens(_ value: Int) -> String {
        if value >= 100_000_000 {
            return "\(oneDecimal(Double(value) / 100_000_000)) 亿"
        }
        if value >= 10_000 {
            return "\(oneDecimal(Double(value) / 10_000)) 万"
        }
        return value.formatted()
    }

    static func duration(_ value: TimeInterval) -> String {
        let totalMinutes = Int(value) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours) 小时 \(minutes) 分"
        }
        return "\(minutes) 分"
    }

    private static func oneDecimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
