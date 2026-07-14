struct ProjectCompletionDetector {
    private var previousStates: [String: ProjectRunState]?

    mutating func completedProjects(in projects: [ProjectActivity]) -> [ProjectActivity] {
        let currentStates = Dictionary(
            uniqueKeysWithValues: projects.map { ($0.name, $0.state) }
        )
        defer { previousStates = currentStates }

        guard let previousStates else { return [] }
        return projects.filter {
            $0.state == .completed && previousStates[$0.name] == .running
        }
    }
}
