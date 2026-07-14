import Foundation

enum UsageAggregator {
    static func makeSnapshot(
        sessions: [SessionSummary],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> MonitorSnapshot {
        let groupedByDay = Dictionary(grouping: sessions) {
            calendar.startOfDay(for: $0.date)
        }
        let dailyActivity = groupedByDay.map { date, values in
            UsageDay(
                date: date,
                tokens: values.reduce(0) { $0 + $1.totalTokens },
                sessions: values.count
            )
        }.sorted { $0.date < $1.date }

        let newestQuota = sessions
            .filter { $0.weeklyUsedPercent != nil }
            .max { $0.updatedAt < $1.updatedAt }
        let remainingPercent = newestQuota?.weeklyUsedPercent.map {
            max(0, min(100, 100 - $0))
        }

        let groupedByProject = Dictionary(grouping: sessions, by: \.projectName)
        let projects = groupedByProject.compactMap { projectName, values -> ProjectActivity? in
            guard let latest = values.max(by: { $0.updatedAt < $1.updatedAt }) else {
                return nil
            }
            if latest.state == .completed,
               now.timeIntervalSince(latest.updatedAt) > 1_800 {
                return nil
            }
            return ProjectActivity(
                name: projectName,
                state: latest.state,
                updatedAt: latest.updatedAt
            )
        }.sortedForMenu

        let activeDates = Set(
            dailyActivity
                .filter { $0.tokens > 0 }
                .map { calendar.startOfDay(for: $0.date) }
        )
        let streaks = streakLengths(
            activeDates: activeDates,
            now: now,
            calendar: calendar
        )

        return MonitorSnapshot(
            weeklyQuota: WeeklyQuota(
                remainingPercent: remainingPercent,
                resetsAt: newestQuota?.weeklyResetsAt
            ),
            dailyActivity: dailyActivity,
            lifetimeTokens: sessions.reduce(0) { $0 + $1.totalTokens },
            peakTokens: sessions.map(\.totalTokens).max() ?? 0,
            longestTaskDuration: sessions.map(\.longestTaskDuration).max() ?? 0,
            currentStreakDays: streaks.current,
            longestStreakDays: streaks.longest,
            projects: projects,
            lastUpdatedAt: sessions.map(\.updatedAt).max()
        )
    }

    static func streakLengths(
        activeDates: Set<Date>,
        now: Date,
        calendar: Calendar
    ) -> (current: Int, longest: Int) {
        let sorted = activeDates.sorted()
        var longest = 0
        var run = 0
        var previous: Date?

        for date in sorted {
            if let previous,
               calendar.dateComponents([.day], from: previous, to: date).day == 1 {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            previous = date
        }

        var current = 0
        var cursor = calendar.startOfDay(for: now)
        while activeDates.contains(cursor) {
            current += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }

        return (current, longest)
    }
}
