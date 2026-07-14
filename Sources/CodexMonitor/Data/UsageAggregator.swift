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

        let namedSessions = sessions.compactMap { session in
            session.projectName.map { (name: $0, session: session) }
        }
        let groupedByProject = Dictionary(grouping: namedSessions, by: \.name)
        let projects = groupedByProject.compactMap { projectName, values -> ProjectActivity? in
            guard let latest = values
                .map(\.session)
                .max(by: { $0.updatedAt < $1.updatedAt }) else {
                return nil
            }
            return ProjectActivity(
                name: projectName,
                state: latest.state,
                updatedAt: latest.updatedAt
            )
        }
        .visibleForMenu(at: now)
        .sortedForMenu

        let newestSessionsByID = namedSessions.reduce(
            into: [String: (name: String, session: SessionSummary)]()
        ) { result, item in
            guard let existing = result[item.session.sessionID] else {
                result[item.session.sessionID] = item
                return
            }
            if item.session.updatedAt > existing.session.updatedAt {
                result[item.session.sessionID] = item
            }
        }
        let sessionActivities = newestSessionsByID.values.map { item in
            SessionActivity(
                id: item.session.sessionID,
                projectName: item.name,
                displayName: SessionDisplayName.make(
                    agentNickname: item.session.agentNickname,
                    startedAt: item.session.date
                ),
                state: item.session.state,
                updatedAt: item.session.updatedAt
            )
        }
        .sorted {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt < $1.updatedAt }
            return $0.id < $1.id
        }

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
            sessions: sessionActivities,
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
