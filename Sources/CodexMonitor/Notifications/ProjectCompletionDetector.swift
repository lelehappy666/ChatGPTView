import Foundation

enum CompletionNotificationPolicy {
    static let freshness: TimeInterval = 120
}

struct SessionCompletionDetector {
    private var seenCompletedTurns: Set<String>?

    mutating func completedSessions(in sessions: [SessionActivity]) -> [SessionActivity] {
        let newestSessions = sessions
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

        let completedWithIdentity = newestSessions.compactMap { session -> (String, SessionActivity)? in
            guard session.isTopLevel,
                  session.state == .completed,
                  let turnID = session.turnID else { return nil }
            return ("\(session.id)::\(turnID)", session)
        }

        guard var seenCompletedTurns else {
            self.seenCompletedTurns = Set(completedWithIdentity.map(\.0))
            return []
        }

        let completed = completedWithIdentity.compactMap { key, session in
            seenCompletedTurns.insert(key).inserted ? session : nil
        }
        self.seenCompletedTurns = seenCompletedTurns
        return completed
    }
}

enum CompletionConfirmation {
    static func matches(
        candidate: SessionActivity,
        latest: SessionActivity,
        now: Date,
        freshness: TimeInterval
    ) -> Bool {
        guard candidate.isTopLevel,
              latest.isTopLevel,
              let candidateTurnID = candidate.turnID else { return false }
        let age = now.timeIntervalSince(latest.updatedAt)
        return latest.id == candidate.id &&
            latest.state == .completed &&
            latest.turnID == candidateTurnID &&
            latest.updatedAt == candidate.updatedAt &&
            age >= 0 &&
            age <= freshness
    }
}

enum CompletionPendingPolicy {
    static func keysToCancel(
        pendingKeys: [String],
        latest: SessionActivity
    ) -> [String] {
        let prefix = "\(latest.id)::"
        let currentKey = latest.turnID.map { "\(latest.id)::\($0)" }
        return pendingKeys.filter { key in
            key.hasPrefix(prefix) &&
                (!latest.isTopLevel || latest.state != .completed || key != currentKey)
        }.sorted()
    }
}
