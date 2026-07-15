import XCTest
@testable import CodexMonitor

final class AppIntegrationTests: XCTestCase {
    func testSessionsRootUsesCodexDirectoryInsideHome() {
        let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)

        XCTAssertEqual(
            AppPaths.sessionsRoot(home: home).path,
            "/Users/tester/.codex/sessions"
        )
    }

    func testPageNavigationClampsToFourPages() {
        XCTAssertEqual(PageNavigation.target(from: 0, delta: 30), 0)
        XCTAssertEqual(PageNavigation.target(from: 0, delta: -30), 1)
        XCTAssertEqual(PageNavigation.target(from: 2, delta: -30), 3)
        XCTAssertEqual(PageNavigation.target(from: 3, delta: -30), 3)
        XCTAssertEqual(PageNavigation.target(from: 3, delta: 30), 2)
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
        XCTAssertEqual(plist["CFBundleShortVersionString"] as? String, "0.1.4")
        XCTAssertEqual(plist["CFBundleVersion"] as? String, "5")
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
