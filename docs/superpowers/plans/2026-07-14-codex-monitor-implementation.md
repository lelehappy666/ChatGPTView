# Codex Monitor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个原生 macOS 菜单栏应用，在顶部菜单栏和刘海悬浮窗口中展示 Codex 周额度、每日活动、累计统计与真实项目状态。

**Architecture:** 使用 SwiftUI 构建三页刘海内容，AppKit 管理 `NSStatusItem`、无边框 `NSPanel` 和全局鼠标事件。数据层只读扫描 `~/.codex/sessions/**/*.jsonl`，把 Codex 事件归一化为 `MonitorSnapshot`；视图只观察快照，不直接读取文件。

**Tech Stack:** Swift 6、SwiftUI、AppKit、Foundation、XCTest、Swift Package Manager、FSEvents、shell `.app` 打包脚本。

## Global Constraints

- 目标平台为 macOS 14 或更高版本，Apple Silicon 为主要验证架构。
- 刘海窗口基准尺寸固定为 `328 × 198 px`，弹窗只有周额度、每日活动、统计总览三页。
- 产品只展示周额度，禁止显示 5 小时额度。
- 项目状态只在菜单栏显示；每 4 秒轮播一个真实项目名，悬停暂停。
- 任何无法从本机可靠读取的值显示 `—`，不得估算或伪造。
- 不读取项目文件正文，不记录提示词或模型输出正文，不向外部服务器发送数据。
- 所有数据必须完整可见；统计页底部指标与分页圆点至少保留 12 px 安全距离。
- 当前机器必须先安装完整 Xcode 并执行 `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`。现有 Command Line Tools 的 Swift 编译器与 SDK 不匹配，不能构建项目。

## File Structure

```text
Package.swift                                      SwiftPM targets and macOS floor
Sources/CodexMonitor/App/CodexMonitorApp.swift     application entry point
Sources/CodexMonitor/App/AppDelegate.swift         menu bar and notch lifecycle
Sources/CodexMonitor/Domain/MonitorModels.swift    immutable domain models
Sources/CodexMonitor/Data/CodexJSONL.swift         JSONL event decoding
Sources/CodexMonitor/Data/SessionScanner.swift     read-only session discovery/parsing
Sources/CodexMonitor/Data/UsageAggregator.swift    daily, lifetime, streak, project aggregation
Sources/CodexMonitor/Data/SessionDirectoryWatcher.swift  FSEvents wrapper
Sources/CodexMonitor/Data/MonitorStore.swift       refresh/debounce/last-good snapshot
Sources/CodexMonitor/MenuBar/MenuBarController.swift     NSStatusItem host
Sources/CodexMonitor/MenuBar/MenuBarContentView.swift    quota and project ticker
Sources/CodexMonitor/Notch/NotchGeometry.swift     screen/notch positioning
Sources/CodexMonitor/Notch/NotchWindowController.swift   hover and NSPanel behavior
Sources/CodexMonitor/Notch/NotchDashboardView.swift      three-page pager
Sources/CodexMonitor/Notch/WeeklyQuotaPage.swift         page 1
Sources/CodexMonitor/Notch/DailyActivityPage.swift       page 2
Sources/CodexMonitor/Notch/StatisticsPage.swift          page 3
Sources/CodexMonitor/Notch/ActivityHeatmap.swift         reusable day grid
Tests/CodexMonitorTests/Fixtures/session-running.jsonl    deterministic parser fixture
Tests/CodexMonitorTests/Fixtures/session-failed.jsonl     deterministic failed task fixture
Tests/CodexMonitorTests/JSONLDecoderTests.swift           decoder tests
Tests/CodexMonitorTests/UsageAggregatorTests.swift        aggregation tests
Tests/CodexMonitorTests/NotchGeometryTests.swift          placement tests
Tests/CodexMonitorTests/LayoutContractTests.swift         fixed layout safety tests
scripts/package-app.sh                              create dist/Codex Monitor.app
Resources/Info.plist                               agent app metadata and LSUIElement
```

---

### Task 1: Toolchain Gate, Package Bootstrap, and Domain Models

**Files:**
- Create: `Package.swift`
- Create: `Sources/CodexMonitor/Domain/MonitorModels.swift`
- Create: `Tests/CodexMonitorTests/MonitorModelsTests.swift`

**Interfaces:**
- Produces: `MonitorSnapshot`, `UsageDay`, `ProjectActivity`, `ProjectRunState`, and `WeeklyQuota`.
- Consumes: no earlier task.

- [ ] **Step 1: Verify the full Xcode toolchain**

Run:

```bash
xcodebuild -version
xcrun swift --version
```

Expected: both commands succeed. If `xcodebuild` reports that the active developer directory is Command Line Tools, install Xcode and select it before continuing.

- [ ] **Step 2: Write the failing domain-model test**

```swift
import XCTest
@testable import CodexMonitor

final class MonitorModelsTests: XCTestCase {
    func testProjectPriorityOrdersFailedBeforeRunningBeforeCompleted() {
        let items = [
            ProjectActivity(name: "Done", state: .completed, updatedAt: .distantPast),
            ProjectActivity(name: "Run", state: .running, updatedAt: .now),
            ProjectActivity(name: "Fail", state: .failed, updatedAt: .now)
        ]
        XCTAssertEqual(items.sortedForMenu.map(\.name), ["Fail", "Run", "Done"])
    }

    func testEmptySnapshotUsesUnavailableWeeklyQuota() {
        XCTAssertNil(MonitorSnapshot.empty.weeklyQuota.remainingPercent)
    }
}
```

- [ ] **Step 3: Run the test and confirm the package is absent**

Run: `swift test --filter MonitorModelsTests`

Expected: FAIL because `Package.swift` and `CodexMonitor` do not exist.

- [ ] **Step 4: Create the package and models**

```swift
// Package.swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CodexMonitor",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "CodexMonitor", targets: ["CodexMonitor"])],
    targets: [
        .executableTarget(name: "CodexMonitor", path: "Sources/CodexMonitor"),
        .testTarget(
            name: "CodexMonitorTests",
            dependencies: ["CodexMonitor"],
            path: "Tests/CodexMonitorTests",
            resources: [.copy("Fixtures")]
        )
    ]
)
```

```swift
// Sources/CodexMonitor/Domain/MonitorModels.swift
import Foundation

struct WeeklyQuota: Equatable, Sendable {
    let remainingPercent: Double?
    let resetsAt: Date?
}

struct UsageDay: Identifiable, Equatable, Sendable {
    var id: Date { date }
    let date: Date
    let tokens: Int
    let sessions: Int
}

enum ProjectRunState: Int, Codable, Sendable {
    case failed = 0
    case running = 1
    case completed = 2
}

struct ProjectActivity: Identifiable, Equatable, Sendable {
    var id: String { name }
    let name: String
    let state: ProjectRunState
    let updatedAt: Date
}

extension Array where Element == ProjectActivity {
    var sortedForMenu: [ProjectActivity] {
        sorted {
            if $0.state.rawValue != $1.state.rawValue { return $0.state.rawValue < $1.state.rawValue }
            return $0.updatedAt > $1.updatedAt
        }
    }
}

struct MonitorSnapshot: Equatable, Sendable {
    let weeklyQuota: WeeklyQuota
    let dailyActivity: [UsageDay]
    let lifetimeTokens: Int
    let peakTokens: Int
    let longestTaskDuration: TimeInterval
    let currentStreakDays: Int
    let longestStreakDays: Int
    let projects: [ProjectActivity]
    let lastUpdatedAt: Date?

    static let empty = MonitorSnapshot(
        weeklyQuota: WeeklyQuota(remainingPercent: nil, resetsAt: nil),
        dailyActivity: [], lifetimeTokens: 0, peakTokens: 0,
        longestTaskDuration: 0, currentStreakDays: 0, longestStreakDays: 0,
        projects: [], lastUpdatedAt: nil
    )
}
```

- [ ] **Step 5: Run tests**

Run: `swift test --filter MonitorModelsTests`

Expected: PASS, 2 tests.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/CodexMonitor/Domain Tests/CodexMonitorTests/MonitorModelsTests.swift
git commit -m "feat: bootstrap Codex Monitor domain"
```

---

### Task 2: Decode Codex JSONL Sessions Without Reading Message Bodies

**Files:**
- Create: `Sources/CodexMonitor/Data/CodexJSONL.swift`
- Create: `Sources/CodexMonitor/Data/SessionScanner.swift`
- Create: `Tests/CodexMonitorTests/Fixtures/session-running.jsonl`
- Create: `Tests/CodexMonitorTests/Fixtures/session-failed.jsonl`
- Create: `Tests/CodexMonitorTests/JSONLDecoderTests.swift`

**Interfaces:**
- Consumes: domain types from Task 1.
- Produces: `SessionSummary` and `SessionScanner.scan(root:) async throws -> [SessionSummary]`.

- [ ] **Step 1: Add sanitized fixtures**

```jsonl
{"type":"session_meta","payload":{"type":"session_meta","timestamp":"2026-07-14T09:00:00Z","cwd":"/Users/test/Projects/CodexMonitor"}}
{"type":"event_msg","payload":{"type":"task_started","started_at":1783990800}}
{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":142000}},"rate_limits":{"primary":{"used_percent":25.0,"window_minutes":10080,"resets_at":1784510985}}}}
```

```jsonl
{"type":"session_meta","payload":{"type":"session_meta","timestamp":"2026-07-13T09:00:00Z","cwd":"/Users/test/Projects/DataSync"}}
{"type":"event_msg","payload":{"type":"task_started","started_at":1783904400}}
{"type":"event_msg","payload":{"type":"turn_aborted","completed_at":1783908000,"duration_ms":3600000,"reason":"tool_failed"}}
{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":310000}}}}
```

- [ ] **Step 2: Write decoder tests**

```swift
import XCTest
@testable import CodexMonitor

final class JSONLDecoderTests: XCTestCase {
    func testRunningFixtureExtractsWeeklyQuotaAndProjectName() throws {
        let summary = try SessionScanner.parseFixture(named: "session-running")
        XCTAssertEqual(summary.projectName, "CodexMonitor")
        XCTAssertEqual(summary.totalTokens, 142_000)
        XCTAssertEqual(summary.weeklyUsedPercent, 25)
        XCTAssertEqual(summary.state, .running)
    }

    func testAbortedFixtureIsFailedAndKeepsDuration() throws {
        let summary = try SessionScanner.parseFixture(named: "session-failed")
        XCTAssertEqual(summary.projectName, "DataSync")
        XCTAssertEqual(summary.state, .failed)
        XCTAssertEqual(summary.longestTaskDuration, 3_600)
    }
}
```

- [ ] **Step 3: Run tests to verify failure**

Run: `swift test --filter JSONLDecoderTests`

Expected: FAIL because `SessionScanner` is undefined.

- [ ] **Step 4: Add the decoder and summary**

```swift
// Sources/CodexMonitor/Data/CodexJSONL.swift
import Foundation

struct CodexEnvelope: Decodable {
    let type: String
    let payload: Payload

    struct Payload: Decodable {
        let type: String?
        let timestamp: String?
        let cwd: String?
        let startedAt: Double?
        let completedAt: Double?
        let durationMS: Double?
        let reason: String?
        let info: TokenInfo?
        let rateLimits: RateLimits?

        enum CodingKeys: String, CodingKey {
            case type, timestamp, cwd, reason, info
            case startedAt = "started_at"
            case completedAt = "completed_at"
            case durationMS = "duration_ms"
            case rateLimits = "rate_limits"
        }
    }
}

struct TokenInfo: Decodable {
    let totalTokenUsage: TokenUsage?
    enum CodingKeys: String, CodingKey { case totalTokenUsage = "total_token_usage" }
}

struct TokenUsage: Decodable {
    let totalTokens: Int?
    enum CodingKeys: String, CodingKey { case totalTokens = "total_tokens" }
}

struct RateLimits: Decodable {
    let primary: RateWindow?
}

struct RateWindow: Decodable {
    let usedPercent: Double?
    let windowMinutes: Int?
    let resetsAt: Double?
    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case windowMinutes = "window_minutes"
        case resetsAt = "resets_at"
    }
}

struct SessionSummary: Equatable, Sendable {
    let date: Date
    let projectName: String
    let totalTokens: Int
    let longestTaskDuration: TimeInterval
    let state: ProjectRunState
    let updatedAt: Date
    let weeklyUsedPercent: Double?
    let weeklyResetsAt: Date?
}
```

- [ ] **Step 5: Add a line-by-line scanner**

`SessionScanner` must decode only `session_meta`, `task_started`, `task_complete`, `turn_aborted`, and `token_count`. It must skip `response_item`, `user_message`, and `agent_message` without decoding their bodies. The final state is `.running` when the last terminal event is `task_started`, `.failed` for `turn_aborted`, and `.completed` for `task_complete`. Use the final token total in the file, not the sum of cumulative token events.

```swift
// Sources/CodexMonitor/Data/SessionScanner.swift
import Foundation

enum SessionScanner {
    static func scan(root: URL) async throws -> [SessionSummary] {
        let keys: [URLResourceKey] = [.isRegularFileKey]
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "jsonl" } ?? []
        return try files.compactMap(parseFile)
    }

    static func parseFile(_ url: URL) throws -> SessionSummary? {
        let text = try String(contentsOf: url, encoding: .utf8)
        let decoder = JSONDecoder()
        var timestamp: Date?
        var cwd: String?
        var tokens = 0
        var longest: TimeInterval = 0
        var state: ProjectRunState = .completed
        var updated = Date.distantPast
        var weeklyUsed: Double?
        var weeklyReset: Date?

        for line in text.split(separator: "\n") {
            guard line.contains("session_meta") || line.contains("task_started") ||
                    line.contains("task_complete") || line.contains("turn_aborted") ||
                    line.contains("token_count"),
                  let envelope = try? decoder.decode(CodexEnvelope.self, from: Data(line.utf8)) else { continue }
            let payload = envelope.payload
            switch payload.type {
            case "session_meta":
                cwd = payload.cwd
                timestamp = payload.timestamp.flatMap(ISO8601DateFormatter().date)
            case "task_started":
                state = .running
                updated = payload.startedAt.map(Date.init(timeIntervalSince1970:)) ?? updated
            case "task_complete":
                state = .completed
                longest = max(longest, (payload.durationMS ?? 0) / 1_000)
                updated = payload.completedAt.map(Date.init(timeIntervalSince1970:)) ?? updated
            case "turn_aborted":
                state = .failed
                longest = max(longest, (payload.durationMS ?? 0) / 1_000)
                updated = payload.completedAt.map(Date.init(timeIntervalSince1970:)) ?? updated
            case "token_count":
                tokens = payload.info?.totalTokenUsage?.totalTokens ?? tokens
                if payload.rateLimits?.primary?.windowMinutes == 10_080 {
                    weeklyUsed = payload.rateLimits?.primary?.usedPercent
                    weeklyReset = payload.rateLimits?.primary?.resetsAt.map(Date.init(timeIntervalSince1970:))
                }
            default: break
            }
        }
        guard let timestamp, let cwd else { return nil }
        return SessionSummary(
            date: timestamp, projectName: URL(fileURLWithPath: cwd).lastPathComponent,
            totalTokens: tokens, longestTaskDuration: longest, state: state,
            updatedAt: updated == .distantPast ? timestamp : updated,
            weeklyUsedPercent: weeklyUsed, weeklyResetsAt: weeklyReset
        )
    }

    static func parseFixture(named name: String) throws -> SessionSummary {
        let url = Bundle.module.url(forResource: name, withExtension: "jsonl", subdirectory: "Fixtures")!
        return try XCTUnwrapCompat(parseFile(url))
    }
}

private func XCTUnwrapCompat<T>(_ value: T?) throws -> T {
    guard let value else { throw CocoaError(.fileReadCorruptFile) }
    return value
}
```

- [ ] **Step 6: Run tests and commit**

Run: `swift test --filter JSONLDecoderTests`

Expected: PASS, 2 tests.

```bash
git add Sources/CodexMonitor/Data Tests/CodexMonitorTests
git commit -m "feat: parse local Codex session events"
```

---

### Task 3: Aggregate Weekly Quota, Daily Activity, Statistics, and Projects

**Files:**
- Create: `Sources/CodexMonitor/Data/UsageAggregator.swift`
- Create: `Tests/CodexMonitorTests/UsageAggregatorTests.swift`

**Interfaces:**
- Consumes: `[SessionSummary]`.
- Produces: `UsageAggregator.makeSnapshot(sessions:now:calendar:) -> MonitorSnapshot`.

- [ ] **Step 1: Write failing aggregation tests**

Create three summaries across two adjacent days and two projects. Assert:

```swift
func testAggregationUsesNewestWeeklyWindowAndGroupsDays() {
    let snapshot = UsageAggregator.makeSnapshot(sessions: fixtures, now: dayTwo, calendar: utc)
    XCTAssertEqual(snapshot.weeklyQuota.remainingPercent, 75)
    XCTAssertEqual(snapshot.dailyActivity.map(\.tokens), [100, 350])
    XCTAssertEqual(snapshot.lifetimeTokens, 450)
    XCTAssertEqual(snapshot.peakTokens, 300)
    XCTAssertEqual(snapshot.currentStreakDays, 2)
    XCTAssertEqual(snapshot.projects.map(\.name), ["Broken", "Active"])
}
```

- [ ] **Step 2: Run the test to verify failure**

Run: `swift test --filter UsageAggregatorTests`

Expected: FAIL because `UsageAggregator` is undefined.

- [ ] **Step 3: Implement deterministic aggregation**

```swift
// Sources/CodexMonitor/Data/UsageAggregator.swift
import Foundation

enum UsageAggregator {
    static func makeSnapshot(
        sessions: [SessionSummary], now: Date = .now, calendar: Calendar = .current
    ) -> MonitorSnapshot {
        let byDay = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }
        let days = byDay.map { date, values in
            UsageDay(date: date, tokens: values.reduce(0) { $0 + $1.totalTokens }, sessions: values.count)
        }.sorted { $0.date < $1.date }

        let newestQuota = sessions
            .filter { $0.weeklyUsedPercent != nil }
            .max { $0.updatedAt < $1.updatedAt }
        let remaining = newestQuota?.weeklyUsedPercent.map { max(0, min(100, 100 - $0)) }

        let projectGroups = Dictionary(grouping: sessions, by: \.projectName)
        let projects = projectGroups.map { name, values -> ProjectActivity in
            let latest = values.max { $0.updatedAt < $1.updatedAt }!
            return ProjectActivity(name: name, state: latest.state, updatedAt: latest.updatedAt)
        }.filter { item in
            item.state != .completed || now.timeIntervalSince(item.updatedAt) <= 1_800
        }.sortedForMenu

        let activeDates = Set(days.filter { $0.tokens > 0 }.map { calendar.startOfDay(for: $0.date) })
        let streaks = streakLengths(activeDates: activeDates, now: now, calendar: calendar)

        return MonitorSnapshot(
            weeklyQuota: WeeklyQuota(remainingPercent: remaining, resetsAt: newestQuota?.weeklyResetsAt),
            dailyActivity: days, lifetimeTokens: sessions.reduce(0) { $0 + $1.totalTokens },
            peakTokens: sessions.map(\.totalTokens).max() ?? 0,
            longestTaskDuration: sessions.map(\.longestTaskDuration).max() ?? 0,
            currentStreakDays: streaks.current, longestStreakDays: streaks.longest,
            projects: projects, lastUpdatedAt: sessions.map(\.updatedAt).max()
        )
    }

    static func streakLengths(activeDates: Set<Date>, now: Date, calendar: Calendar) -> (current: Int, longest: Int) {
        let sorted = activeDates.sorted()
        var longest = 0, run = 0
        var previous: Date?
        for date in sorted {
            run = previous.flatMap { calendar.dateComponents([.day], from: $0, to: date).day } == 1 ? run + 1 : 1
            longest = max(longest, run)
            previous = date
        }
        var current = 0
        var cursor = calendar.startOfDay(for: now)
        while activeDates.contains(cursor) {
            current += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return (current, longest)
    }
}
```

- [ ] **Step 4: Run all aggregation tests**

Run: `swift test --filter UsageAggregatorTests`

Expected: PASS for daily grouping, weekly remaining, streaks, project order, and 30-minute completion retention.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodexMonitor/Data/UsageAggregator.swift Tests/CodexMonitorTests/UsageAggregatorTests.swift
git commit -m "feat: aggregate Codex usage and project state"
```

---

### Task 4: Live Store, FSEvents Refresh, and Last-Good Snapshot

**Files:**
- Create: `Sources/CodexMonitor/Data/SessionDirectoryWatcher.swift`
- Create: `Sources/CodexMonitor/Data/MonitorStore.swift`
- Create: `Tests/CodexMonitorTests/MonitorStoreTests.swift`

**Interfaces:**
- Consumes: `SessionScanner.scan` and `UsageAggregator.makeSnapshot`.
- Produces: `@MainActor final class MonitorStore: ObservableObject` with `@Published private(set) var snapshot`, `isLoading`, and `errorMessage`.

- [ ] **Step 1: Write a failing refresh-coalescing test**

Use an injected scanner closure and call `requestRefresh()` five times. Assert that the scanner runs once after a 250 ms debounce and that a later scanner error preserves the previous snapshot while setting `errorMessage`.

- [ ] **Step 2: Run the test to verify failure**

Run: `swift test --filter MonitorStoreTests`

Expected: FAIL because `MonitorStore` is undefined.

- [ ] **Step 3: Add an FSEvents wrapper**

Create `SessionDirectoryWatcher` around `FSEventStreamCreate`, watching `~/.codex/sessions` with `kFSEventStreamCreateFlagFileEvents` and 0.5-second latency. The callback invokes a `@Sendable () -> Void`; `stop()` invalidates and releases the stream.

- [ ] **Step 4: Add the main-actor store**

```swift
@MainActor
final class MonitorStore: ObservableObject {
    @Published private(set) var snapshot: MonitorSnapshot = .empty
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let root: URL
    private let scanner: @Sendable (URL) async throws -> [SessionSummary]
    private var refreshTask: Task<Void, Never>?

    init(root: URL, scanner: @escaping @Sendable (URL) async throws -> [SessionSummary] = SessionScanner.scan) {
        self.root = root
        self.scanner = scanner
    }

    func requestRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            do {
                let sessions = try await scanner(root)
                snapshot = UsageAggregator.makeSnapshot(sessions: sessions)
                errorMessage = nil
            } catch {
                errorMessage = "数据可能已过期"
            }
            isLoading = false
        }
    }
}
```

- [ ] **Step 5: Run tests and commit**

Run: `swift test --filter MonitorStoreTests`

Expected: PASS for debounce, success, and last-good-value behavior.

```bash
git add Sources/CodexMonitor/Data Tests/CodexMonitorTests/MonitorStoreTests.swift
git commit -m "feat: refresh Codex data from filesystem events"
```

---

### Task 5: Build the Three Fixed-Size SwiftUI Pages

**Files:**
- Create: `Sources/CodexMonitor/Notch/NotchDashboardView.swift`
- Create: `Sources/CodexMonitor/Notch/WeeklyQuotaPage.swift`
- Create: `Sources/CodexMonitor/Notch/DailyActivityPage.swift`
- Create: `Sources/CodexMonitor/Notch/StatisticsPage.swift`
- Create: `Sources/CodexMonitor/Notch/ActivityHeatmap.swift`
- Create: `Tests/CodexMonitorTests/LayoutContractTests.swift`

**Interfaces:**
- Consumes: `MonitorSnapshot`.
- Produces: `NotchDashboardView(snapshot:reduceMotion:)` sized exactly `328 × 198`.

- [ ] **Step 1: Write layout-contract tests**

Define constants in `NotchLayout` and assert:

```swift
func testDashboardContractLeavesStatisticsSafetySpace() {
    XCTAssertEqual(NotchLayout.size, CGSize(width: 328, height: 198))
    XCTAssertGreaterThanOrEqual(NotchLayout.statisticsBottomSafeArea, 12)
    XCTAssertEqual(NotchLayout.pageCount, 3)
}
```

- [ ] **Step 2: Run the test and confirm failure**

Run: `swift test --filter LayoutContractTests`

Expected: FAIL because `NotchLayout` is undefined.

- [ ] **Step 3: Add the fixed layout and pager**

```swift
enum NotchLayout {
    static let size = CGSize(width: 328, height: 198)
    static let contentTop: CGFloat = 39
    static let pagerHeight: CGFloat = 18
    static let statisticsBottomSafeArea: CGFloat = 12
    static let pageCount = 3
}

struct NotchDashboardView: View {
    let snapshot: MonitorSnapshot
    let reduceMotion: Bool
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            WeeklyQuotaPage(snapshot: snapshot).tag(0)
            DailyActivityPage(snapshot: snapshot).tag(1)
            StatisticsPage(snapshot: snapshot).tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(width: 328, height: 198)
        .background(Color.black)
        .clipShape(.rect(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
        .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: page)
    }
}
```

- [ ] **Step 4: Add the weekly page**

Render remaining percentage, used percentage, reset countdown, a six-point progress bar, and seven daily intensity strips. Use `—` when quota is unavailable. Do not add any 5-hour field.

- [ ] **Step 5: Add the daily activity heatmap**

`ActivityHeatmap` renders the last 56 calendar days as seven 8-point rows with 2-point gaps. Normalize intensity against the highest daily token count. `DailyActivityPage` places the heatmap in a 108-point column and the four text statistics in a flexible second column aligned to `.top`; all rows use fixed line height so none can extend beneath the pager.

- [ ] **Step 6: Add the statistics page**

Use two 39-point high primary cards and three 27-point high secondary strips. Offset the entire statistic group 3 points upward and preserve the 12-point bottom safety area. Format token counts with Chinese `亿/万` units and duration as `小时/分`.

- [ ] **Step 7: Run tests and compile**

Run:

```bash
swift test --filter LayoutContractTests
swift build
```

Expected: tests PASS and the executable target compiles.

- [ ] **Step 8: Commit**

```bash
git add Sources/CodexMonitor/Notch Tests/CodexMonitorTests/LayoutContractTests.swift
git commit -m "feat: add compact three-page notch dashboard"
```

---

### Task 6: Position and Animate the Notch NSPanel

**Files:**
- Create: `Sources/CodexMonitor/Notch/NotchGeometry.swift`
- Create: `Sources/CodexMonitor/Notch/NotchWindowController.swift`
- Create: `Tests/CodexMonitorTests/NotchGeometryTests.swift`

**Interfaces:**
- Consumes: `NotchDashboardView` and `MonitorStore`.
- Produces: `NotchGeometry.panelFrame(screen:panelSize:)` and `NotchWindowController.start()`.

- [ ] **Step 1: Write geometry tests**

For a `1512 × 982` visible screen, assert the panel is horizontally centered at the screen top and is `328 × 198`. For a second display with a nonzero origin, assert placement uses that display's coordinates.

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter NotchGeometryTests`

Expected: FAIL because `NotchGeometry` is undefined.

- [ ] **Step 3: Implement pure geometry**

```swift
enum NotchGeometry {
    static func panelFrame(screen: CGRect, panelSize: CGSize = NotchLayout.size) -> CGRect {
        CGRect(
            x: screen.midX - panelSize.width / 2,
            y: screen.maxY - panelSize.height,
            width: panelSize.width,
            height: panelSize.height
        )
    }

    static func hoverRect(screen: CGRect, notchWidth: CGFloat = 164, height: CGFloat = 34) -> CGRect {
        CGRect(x: screen.midX - notchWidth / 2, y: screen.maxY - height, width: notchWidth, height: height)
    }
}
```

- [ ] **Step 4: Implement the panel controller**

Create a borderless, nonactivating `NSPanel` with `.statusBar` level, transparent background, no shadow from AppKit, and `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`. Install local and global mouse-moved monitors. Enter the hover rect for 80 ms before showing; keep open while the pointer is within the panel; delay closing 180 ms. Use `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` to choose spring animation versus crossfade.

- [ ] **Step 5: Run tests and commit**

Run: `swift test --filter NotchGeometryTests`

Expected: PASS for main and secondary display coordinates.

```bash
git add Sources/CodexMonitor/Notch Tests/CodexMonitorTests/NotchGeometryTests.swift
git commit -m "feat: present dashboard from the Mac notch"
```

---

### Task 7: Add the Menu Bar Weekly Quota and Real Project Ticker

**Files:**
- Create: `Sources/CodexMonitor/MenuBar/MenuBarController.swift`
- Create: `Sources/CodexMonitor/MenuBar/MenuBarContentView.swift`
- Create: `Tests/CodexMonitorTests/ProjectTickerTests.swift`

**Interfaces:**
- Consumes: `MonitorStore.snapshot` and `ProjectActivity.sortedForMenu`.
- Produces: `MenuBarController.start()` and a 4-second rotating project index.

- [ ] **Step 1: Write ticker-state tests**

Test that an empty project list hides the ticker, index wraps after the last item, failed projects appear first, and pausing prevents index changes.

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter ProjectTickerTests`

Expected: FAIL because `ProjectTickerState` is undefined.

- [ ] **Step 3: Implement ticker state**

```swift
@MainActor
final class ProjectTickerState: ObservableObject {
    @Published private(set) var index = 0
    @Published var isPaused = false
    var projects: [ProjectActivity] = [] { didSet { index = min(index, max(0, projects.count - 1)) } }

    func advance() {
        guard !isPaused, !projects.isEmpty else { return }
        index = (index + 1) % projects.count
    }
}
```

- [ ] **Step 4: Build the menu bar content**

Use a monochrome knot-shaped symbol, `Week NN%`, the current real project name, localized state text, colored status dot, and `N 项目`. Limit the name to 104 points and truncate only at the tail. Run a 4-second timer; pause on hover. Blue means running, green completed, red failed.

- [ ] **Step 5: Host it in NSStatusItem**

Create an `NSStatusItem` with variable length and set its button view to an `NSHostingView<MenuBarContentView>`. The menu provides only `刷新数据` and `退出 Codex Monitor`; it must not duplicate the project page removed from the design.

- [ ] **Step 6: Run tests and commit**

Run: `swift test --filter ProjectTickerTests`

Expected: PASS for wrap, pause, empty, and priority behavior.

```bash
git add Sources/CodexMonitor/MenuBar Tests/CodexMonitorTests/ProjectTickerTests.swift
git commit -m "feat: show weekly quota and project ticker in menu bar"
```

---

### Task 8: Integrate the App, Package a Launchable .app, and Verify

**Files:**
- Create: `Sources/CodexMonitor/App/CodexMonitorApp.swift`
- Create: `Sources/CodexMonitor/App/AppDelegate.swift`
- Create: `Resources/Info.plist`
- Create: `scripts/package-app.sh`
- Create: `.gitignore`
- Modify: `Package.swift`

**Interfaces:**
- Consumes: all earlier components.
- Produces: `dist/Codex Monitor.app` and the final running application.

- [ ] **Step 1: Wire application lifecycle**

```swift
import SwiftUI

@main
struct CodexMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}
```

`AppDelegate.applicationDidFinishLaunching` creates `MonitorStore` rooted at `~/.codex/sessions`, starts the watcher, requests the first refresh, then starts `MenuBarController` and `NotchWindowController`. Set `NSApp.setActivationPolicy(.accessory)`.

- [ ] **Step 2: Add app metadata**

`Info.plist` must set `CFBundleIdentifier` to `com.dafeng.codexmonitor`, `CFBundleName` to `Codex Monitor`, `CFBundleExecutable` to `CodexMonitor`, `LSUIElement` to `true`, and minimum system version to `14.0`.

- [ ] **Step 3: Add a deterministic packaging script**

```bash
#!/usr/bin/env bash
set -euo pipefail
swift build -c release
APP="dist/Codex Monitor.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/CodexMonitor "$APP/Contents/MacOS/CodexMonitor"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
echo "$APP"
```

- [ ] **Step 4: Ignore generated files**

```gitignore
.build/
dist/
.superpowers/
.DS_Store
```

- [ ] **Step 5: Run the complete automated suite**

Run:

```bash
swift test
swift build -c release
bash scripts/package-app.sh
codesign --verify --deep --strict "dist/Codex Monitor.app"
```

Expected: all tests pass, release build succeeds, `.app` exists, and code-sign verification exits 0.

- [ ] **Step 6: Run manual macOS acceptance checks**

Launch `dist/Codex Monitor.app` and verify:

1. Menu bar shows the monochrome icon, only weekly quota, a real project name, state text, and project count.
2. Project name changes after 4 seconds and pauses on hover.
3. Moving to the notch opens the `328 × 198` window without covering the right-side system menu.
4. Trackpad, mouse wheel, and pager dots switch exactly three pages.
5. Daily activity shows all four right-side values without clipping.
6. Statistics page shows all five values with at least 12 points above the pager.
7. Removing access to the sessions directory leaves the last valid snapshot and displays a stale-data state.
8. Activity Monitor shows no sustained high CPU use while idle.

- [ ] **Step 7: Commit the integrated application**

```bash
git add Sources/CodexMonitor/App Resources scripts Package.swift .gitignore
git commit -m "feat: ship Codex Monitor macOS app"
```

## Plan Self-Review

- Spec coverage: weekly quota, three pages, per-day heatmap, five lifetime statistics, top-only project names/statuses, hover behavior, privacy, stale data, reduced motion, multi-display placement, packaging, and tests are each covered by a task.
- Placeholder scan: no `TBD`, `TODO`, “implement later,” or unspecified error-handling step remains.
- Type consistency: all later tasks consume `MonitorSnapshot`, `SessionSummary`, `ProjectActivity`, and `ProjectRunState` with the signatures introduced in Tasks 1–3.
- Scope: the plan produces one independently runnable macOS application; no cloud backend or account-profile subsystem is included.
