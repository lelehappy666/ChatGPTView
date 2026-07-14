import Foundation

struct SessionCompletionDetector {
    private var latestCompletedUpdates: [String: Date]?

    mutating func completedSessions(in sessions: [SessionActivity]) -> [SessionActivity] {
        guard var completedUpdates = latestCompletedUpdates else {
            latestCompletedUpdates = Dictionary(
                uniqueKeysWithValues: sessions.compactMap { session in
                    guard session.state == .completed else { return nil }
                    return (session.id, session.updatedAt)
                }
            )
            return []
        }

        let completed = sessions.filter { session in
            guard session.state == .completed else { return false }
            guard let previousUpdate = completedUpdates[session.id] else { return true }
            return session.updatedAt > previousUpdate
        }

        for session in sessions where session.state == .completed {
            completedUpdates[session.id] = max(
                completedUpdates[session.id] ?? .distantPast,
                session.updatedAt
            )
        }
        latestCompletedUpdates = completedUpdates
        return completed
    }
}
