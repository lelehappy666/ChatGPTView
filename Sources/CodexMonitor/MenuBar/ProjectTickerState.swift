import Combine
import Foundation

@MainActor
final class ProjectTickerState: ObservableObject {
    @Published private(set) var index = 0
    @Published var isPaused = false

    var projects: [ProjectActivity] = [] {
        didSet {
            index = min(index, max(0, projects.count - 1))
        }
    }

    var currentProject: ProjectActivity? {
        guard projects.indices.contains(index) else { return nil }
        return projects[index]
    }

    func advance() {
        guard !isPaused, !projects.isEmpty else { return }
        index = (index + 1) % projects.count
    }
}
