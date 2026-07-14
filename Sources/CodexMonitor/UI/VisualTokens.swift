import Foundation
import SwiftUI

struct RGBToken: Equatable, Sendable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    static let runningAccent = RGBToken(red: 255, green: 159, blue: 10)

    var hex: String {
        String(format: "%02X%02X%02X", red, green, blue)
    }

    var color: Color {
        Color(
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255
        )
    }
}

enum ActivityTooltip {
    static let presentationDelayMilliseconds = 0

    static func text(
        for day: UsageDay,
        calendar: Calendar = .current
    ) -> String {
        let components = calendar.dateComponents([.month, .day], from: day.date)
        let dateText = "\(components.month ?? 0)月\(components.day ?? 0)日"
        guard day.tokens > 0 || day.sessions > 0 else {
            return "\(dateText) · 无活动"
        }
        return "\(dateText) · \(MetricFormatter.tokens(day.tokens)) Token · \(day.sessions) 个会话"
    }
}

enum ActivityGrid {
    static func days(
        from activity: [UsageDay],
        calendar: Calendar = .current,
        today: Date = .now
    ) -> [UsageDay] {
        let byDate = Dictionary(uniqueKeysWithValues: activity.map {
            (calendar.startOfDay(for: $0.date), $0)
        })
        let end = calendar.startOfDay(for: today)

        return (0..<56).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 55, to: end) else {
                return nil
            }
            return byDate[date] ?? UsageDay(date: date, tokens: 0, sessions: 0)
        }
    }
}
