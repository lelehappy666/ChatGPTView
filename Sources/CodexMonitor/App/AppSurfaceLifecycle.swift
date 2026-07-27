import Foundation

@MainActor
protocol AppSurfaceControlling: AnyObject {
    func start()
    func stop()
}

@MainActor
final class AppSurfaceLifecycle {
    private let surfaces: [AppSurfaceControlling]

    init(surfaces: [AppSurfaceControlling]) {
        self.surfaces = surfaces
    }

    func start() {
        surfaces.forEach { $0.start() }
    }

    func stop() {
        surfaces.forEach { $0.stop() }
    }
}
