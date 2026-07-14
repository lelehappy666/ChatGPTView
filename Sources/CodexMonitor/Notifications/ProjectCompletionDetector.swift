import Foundation

struct SessionCompletionDetector {
    private var latestObservedSessions: [String: SessionActivity]?

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

        guard var observedSessions = latestObservedSessions else {
            latestObservedSessions = Dictionary(
                uniqueKeysWithValues: newestSessions.map { ($0.id, $0) }
            )
            return []
        }

        let completed = newestSessions.filter { session in
            guard session.state == .completed,
                  let previous = observedSessions[session.id] else {
                return false
            }
            return previous.state == .running &&
                session.updatedAt > previous.updatedAt
        }

        for session in newestSessions {
            guard let previous = observedSessions[session.id],
                  previous.updatedAt > session.updatedAt else {
                observedSessions[session.id] = session
                continue
            }
        }
        latestObservedSessions = observedSessions
        return completed
    }
}
