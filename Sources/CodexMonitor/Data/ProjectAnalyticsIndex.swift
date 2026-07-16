import Foundation

actor ProjectAnalyticsIndex {
    private struct IndexedSession: Equatable, Sendable {
        let id: String
        let projectName: String
        let day: Date
        let tokens: Int
        let updatedAt: Date
    }

    private struct ProjectAccumulator {
        var tokens = 0
        var sessionIDs: Set<String> = []
        var activeDays: Set<Date> = []
    }

    private var sessionsByID: [String: IndexedSession] = [:]
    private var buckets: [String: [Date: [String: Int]]] = [:]

    func update(
        sessions: [SessionSummary],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> ProjectAnalyticsSnapshot {
        let current = makeCurrentSessions(sessions, calendar: calendar)

        for (id, oldValue) in sessionsByID where current[id] != oldValue {
            remove(oldValue)
        }
        for (id, newValue) in current where sessionsByID[id] != newValue {
            insert(newValue)
        }

        sessionsByID = current
        return makeSnapshot(now: now, calendar: calendar)
    }

    private func makeCurrentSessions(
        _ summaries: [SessionSummary],
        calendar: Calendar
    ) -> [String: IndexedSession] {
        var result: [String: IndexedSession] = [:]

        for (index, summary) in summaries.enumerated() {
            guard let rawProjectName = summary.projectName else { continue }
            let projectName = rawProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !projectName.isEmpty else { continue }

            let rawID = summary.sessionID.trimmingCharacters(in: .whitespacesAndNewlines)
            let id = rawID.isEmpty
                ? "legacy:\(projectName):\(summary.date.timeIntervalSince1970):\(index)"
                : rawID
            let candidate = IndexedSession(
                id: id,
                projectName: projectName,
                day: calendar.startOfDay(for: summary.date),
                tokens: max(0, summary.totalTokens),
                updatedAt: summary.updatedAt
            )

            guard let existing = result[id] else {
                result[id] = candidate
                continue
            }
            if isNewer(candidate, than: existing) {
                result[id] = candidate
            }
        }

        return result
    }

    private func isNewer(_ candidate: IndexedSession, than existing: IndexedSession) -> Bool {
        if candidate.updatedAt != existing.updatedAt {
            return candidate.updatedAt > existing.updatedAt
        }
        if candidate.tokens != existing.tokens {
            return candidate.tokens > existing.tokens
        }
        return candidate.projectName < existing.projectName
    }

    private func insert(_ session: IndexedSession) {
        var projectBuckets = buckets[session.projectName] ?? [:]
        var dayBucket = projectBuckets[session.day] ?? [:]
        dayBucket[session.id] = session.tokens
        projectBuckets[session.day] = dayBucket
        buckets[session.projectName] = projectBuckets
    }

    private func remove(_ session: IndexedSession) {
        guard var projectBuckets = buckets[session.projectName],
              var dayBucket = projectBuckets[session.day] else {
            return
        }

        dayBucket.removeValue(forKey: session.id)
        if dayBucket.isEmpty {
            projectBuckets.removeValue(forKey: session.day)
        } else {
            projectBuckets[session.day] = dayBucket
        }

        if projectBuckets.isEmpty {
            buckets.removeValue(forKey: session.projectName)
        } else {
            buckets[session.projectName] = projectBuckets
        }
    }

    private func makeSnapshot(now: Date, calendar: Calendar) -> ProjectAnalyticsSnapshot {
        let today = calendar.startOfDay(for: now)
        let cutoffs: [ProjectAnalyticsRange: Date?] = [
            .sevenDays: calendar.date(byAdding: .day, value: -6, to: today),
            .thirtyDays: calendar.date(byAdding: .day, value: -29, to: today),
            .all: nil
        ]

        var periods: [ProjectAnalyticsRange: ProjectAnalyticsPeriodSnapshot] = [:]
        for range in ProjectAnalyticsRange.allCases {
            periods[range] = makePeriod(cutoff: cutoffs[range] ?? nil)
        }
        return ProjectAnalyticsSnapshot(periods: periods, generatedAt: now)
    }

    private func makePeriod(cutoff: Date?) -> ProjectAnalyticsPeriodSnapshot {
        var projects: [(name: String, value: ProjectAccumulator)] = []

        for (projectName, dayBuckets) in buckets {
            var accumulator = ProjectAccumulator()
            for (day, sessionTokens) in dayBuckets {
                if let cutoff, day < cutoff { continue }
                guard !sessionTokens.isEmpty else { continue }

                accumulator.activeDays.insert(day)
                accumulator.sessionIDs.formUnion(sessionTokens.keys)
                for tokens in sessionTokens.values {
                    accumulator.tokens = safeAdd(accumulator.tokens, tokens)
                }
            }
            if !accumulator.sessionIDs.isEmpty {
                projects.append((projectName, accumulator))
            }
        }

        projects.sort { lhs, rhs in
            if lhs.value.tokens != rhs.value.tokens {
                return lhs.value.tokens > rhs.value.tokens
            }
            if lhs.value.sessionIDs.count != rhs.value.sessionIDs.count {
                return lhs.value.sessionIDs.count > rhs.value.sessionIDs.count
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        var totalTokens = 0
        var totalSessions = 0
        for project in projects {
            totalTokens = safeAdd(totalTokens, project.value.tokens)
            totalSessions = safeAdd(totalSessions, project.value.sessionIDs.count)
        }

        var visible = Array(projects.prefix(6))
        if projects.count > 6 {
            visible = Array(projects.prefix(5))
            var remainder = ProjectAccumulator()
            for project in projects.dropFirst(5) {
                remainder.tokens = safeAdd(remainder.tokens, project.value.tokens)
                remainder.sessionIDs.formUnion(project.value.sessionIDs)
                remainder.activeDays.formUnion(project.value.activeDays)
            }
            visible.append(("其他项目", remainder))
        }

        let rows = visible.enumerated().map { index, project in
            ProjectAnalyticsRow(
                id: index == 5 && projects.count > 6 ? "remainder" : "project:\(project.name)",
                name: project.name,
                tokens: project.value.tokens,
                sessions: project.value.sessionIDs.count,
                activeDays: project.value.activeDays.count,
                share: totalTokens > 0
                    ? Double(project.value.tokens) / Double(totalTokens)
                    : 0
            )
        }

        return ProjectAnalyticsPeriodSnapshot(
            activeProjects: projects.count,
            totalTokens: totalTokens,
            totalSessions: totalSessions,
            rows: rows
        )
    }

    private func safeAdd(_ lhs: Int, _ rhs: Int) -> Int {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int.max : sum
    }
}
