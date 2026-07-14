import Foundation

struct ProjectCompletionDetector {
    private var latestObservedUpdates: [String: Date]?

    mutating func completedProjects(in projects: [ProjectActivity]) -> [ProjectActivity] {
        guard var observedUpdates = latestObservedUpdates else {
            latestObservedUpdates = Dictionary(
                uniqueKeysWithValues: projects.map { ($0.name, $0.updatedAt) }
            )
            return []
        }

        let completed = projects.filter { project in
            guard project.state == .completed else { return false }
            guard let previousUpdate = observedUpdates[project.name] else { return true }
            return project.updatedAt > previousUpdate
        }

        for project in projects {
            observedUpdates[project.name] = max(
                observedUpdates[project.name] ?? .distantPast,
                project.updatedAt
            )
        }
        latestObservedUpdates = observedUpdates
        return completed
    }
}
