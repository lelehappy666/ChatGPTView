import XCTest
@testable import CodexMonitor

final class AppIntegrationTests: XCTestCase {
    @MainActor
    func testAppSurfaceLifecycleStartsAndStopsEverySurface() {
        let menu = RecordingAppSurface()
        let notch = RecordingAppSurface()
        let lifecycle = AppSurfaceLifecycle(surfaces: [menu, notch])

        lifecycle.start()
        lifecycle.stop()

        XCTAssertEqual(menu.events, ["启动", "停止"])
        XCTAssertEqual(notch.events, ["启动", "停止"])
    }

    func testSessionsRootUsesCodexDirectoryInsideHome() {
        let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)

        XCTAssertEqual(
            AppPaths.sessionsRoot(home: home).path,
            "/Users/tester/.codex/sessions"
        )
    }

    func testPageNavigationClampsToFivePages() {
        XCTAssertEqual(PageNavigation.target(from: 0, delta: 30), 0)
        XCTAssertEqual(PageNavigation.target(from: 0, delta: -30), 1)
        XCTAssertEqual(PageNavigation.target(from: 3, delta: -30), 4)
        XCTAssertEqual(PageNavigation.target(from: 4, delta: -30), 4)
        XCTAssertEqual(PageNavigation.target(from: 4, delta: 30), 3)
    }

    func testAppMetadataDeclaresPackagedIcon() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let plistData = try Data(
            contentsOf: root.appendingPathComponent("Resources/Info.plist")
        )
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(
                from: plistData,
                format: nil
            ) as? [String: Any]
        )

        XCTAssertEqual(plist["CFBundleIconFile"] as? String, "AppIcon")
        XCTAssertEqual(
            plist["CFBundleShortVersionString"] as? String,
            "0.1.15"
        )
        XCTAssertEqual(plist["CFBundleVersion"] as? String, "16")
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent("Resources/AppIcon.icns").path
            )
        )
    }

    func testNotchRefreshOnlyOccursWhenHiddenPanelWillOpen() {
        XCTAssertTrue(
            NotchRefreshPolicy.shouldRequestRefresh(isPanelVisible: false)
        )
        XCTAssertFalse(
            NotchRefreshPolicy.shouldRequestRefresh(isPanelVisible: true)
        )
    }

    func testAppPeriodicallyRefreshesQuotaAndRefreshesAfterWake() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/CodexMonitor/App/AppDelegate.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("Timer.publish(every: 300"))
        XCTAssertTrue(source.contains("NSWorkspace.didWakeNotification"))
        XCTAssertTrue(source.contains("periodicRefreshCancellable?.cancel()"))
        XCTAssertTrue(source.contains("removeObserver(wakeObserver)"))
    }

    func testGitHubPageAvoidsPerCellViewTreeAndOffscreenBlur() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let githubDirectory = root
            .appendingPathComponent("Sources/CodexMonitor/GitHub")
        let files = ["GitHubActivityPage.swift", "GitHubContributionHeatmap.swift"]
        let source = try files.map {
            try String(
                contentsOf: githubDirectory.appendingPathComponent($0),
                encoding: .utf8
            )
        }.joined(separator: "\n")

        XCTAssertFalse(source.contains("LazyHGrid"))
        XCTAssertFalse(source.contains(".blur("))
        XCTAssertFalse(source.contains(".ultraThinMaterial"))
        XCTAssertTrue(source.contains("Canvas"))
    }

    func testNotchDashboardForcesDarkAppearanceForSecondaryText() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/CodexMonitor/Notch/NotchDashboardView.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains(".environment(\\.colorScheme, .dark)"))
    }

    func testMenuBarStatusItemFitsNotchedDisplayRightSide() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/CodexMonitor/MenuBar/MenuBarController.swift"
            ),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains("withLength: 300"))
        XCTAssertTrue(source.contains("statusItemWidth: CGFloat = 196"))
        XCTAssertTrue(source.contains("withLength: MenuBarLayout.statusItemWidth"))
    }

    func testDashboardRendersOnlyTheVisiblePageDuringTransitions() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/CodexMonitor/Notch/NotchDashboardView.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("switch page"))
        XCTAssertFalse(
            source.contains("NotchLayout.size.width * CGFloat(NotchLayout.pageCount)")
        )
        XCTAssertFalse(source.contains(".offset(x: -CGFloat(page)"))
    }

    func testDashboardSwipeCoexistsWithInteractivePageControls() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/CodexMonitor/Notch/NotchDashboardView.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains(".simultaneousGesture("))
    }

    func testProjectRangeButtonsUseWholeVisualFrameAsHitTarget() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/CodexMonitor/Notch/ProjectAnalyticsPage.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(
            source.contains(
                ".frame(width: 34, height: 19)\n" +
                    "                            .contentShape(Rectangle())"
            )
        )
    }

    func testProjectAnalyticsRowsDoNotClaimMouseFocusFromDashboardSwipe() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/CodexMonitor/Notch/ProjectAnalyticsPage.swift"
            ),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains(".focusable()"))
        XCTAssertFalse(source.contains("@FocusState"))
    }

    func testSummaryPagesUseTheSharedCardLayout() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let directory = root.appendingPathComponent("Sources/CodexMonitor/Notch")
        let pages = [
            "WeeklyQuotaPage.swift",
            "DailyActivityPage.swift",
            "StatisticsPage.swift"
        ]

        for page in pages {
            let source = try String(
                contentsOf: directory.appendingPathComponent(page),
                encoding: .utf8
            )
            XCTAssertTrue(source.contains("DashboardCard"), page)
        }
    }
}

@MainActor
private final class RecordingAppSurface: AppSurfaceControlling {
    var events: [String] = []

    func start() {
        events.append("启动")
    }

    func stop() {
        events.append("停止")
    }
}
