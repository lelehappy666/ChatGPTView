// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CodexMonitor",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CodexMonitor", targets: ["CodexMonitor"])
    ],
    targets: [
        .executableTarget(
            name: "CodexMonitor",
            path: "Sources/CodexMonitor"
        ),
        .testTarget(
            name: "CodexMonitorTests",
            dependencies: ["CodexMonitor"],
            path: "Tests/CodexMonitorTests",
            exclude: ["Fixtures"]
        )
    ]
)
