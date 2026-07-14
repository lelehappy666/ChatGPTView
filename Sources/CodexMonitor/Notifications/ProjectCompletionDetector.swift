import Foundation

struct SessionCompletionDetector {
    private var latestCompletedUpdates: [String: Date]?

    mutating func completedSessions(in sessions: [SessionActivity]) -> [SessionActivity] {
        let newestCompleted = sessions
            .filter { $0.state == .completed }
            .reduce(into: [String: SessionActivity]()) { result, session in
                guard let existing = result[session.id] else {
                    result[session.id] = session
                    return
                }
                if session.updatedAt > existing.updatedAt {
                    result[session.id] = session
                }
            }
            .values
            .sorted {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt < $1.updatedAt }
                return $0.id < $1.id
            }

        guard var completedUpdates = latestCompletedUpdates else {
            var baseline: [String: Date] = [:]
            for session in newestCompleted {
                baseline[session.id] = session.updatedAt
            }
            latestCompletedUpdates = baseline
            return []
        }

        let completed = newestCompleted.filter { session in
            guard let previousUpdate = completedUpdates[session.id] else { return true }
            return session.updatedAt > previousUpdate
        }

        for session in newestCompleted {
            completedUpdates[session.id] = max(
                completedUpdates[session.id] ?? .distantPast,
                session.updatedAt
            )
        }
        latestCompletedUpdates = completedUpdates
        return completed
    }
}
