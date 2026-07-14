# 项目名称过滤与完成通知实施计划

> **供执行人员使用：** 必须使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans`，按任务逐项实施。本计划使用复选框跟踪进度。

**目标：** 排除由用户主目录产生的虚假项目名，并在真实项目从运行中变为完成时发送带声音的 macOS 系统通知。

**架构：** `SessionScanner` 将项目名建模为可选值，`UsageAggregator` 仅从有名称的会话构造项目列表，但所有会话继续参与用量聚合。新增纯状态检测器识别“运行中 → 完成”，通知服务负责权限和投递，`AppDelegate` 负责连接快照与通知。

**技术栈：** Swift 6.2、SwiftUI、Combine、UserNotifications、XCTest、macOS 14+

## 全局约束

- 所有文档使用中文。
- 所有 Git 提交信息使用中文。
- 仅提醒“项目完成”，报错不提醒。
- 首次快照不补发历史通知。
- 无名称会话仍参与全部用量统计。
- 不修改现有刘海窗口尺寸和顶部菜单栏布局。

---

### 任务一：修复用户主目录被识别为项目

**文件：**
- 修改：`Sources/CodexMonitor/Data/CodexJSONL.swift`
- 修改：`Sources/CodexMonitor/Data/SessionScanner.swift`
- 修改：`Sources/CodexMonitor/Data/UsageAggregator.swift`
- 修改：`Tests/CodexMonitorTests/JSONLDecoderTests.swift`
- 修改：`Tests/CodexMonitorTests/UsageAggregatorTests.swift`
- 修改：`Tests/CodexMonitorTests/MonitorStoreTests.swift`

**接口：**
- 输入：会话的 `cwd` 和当前用户主目录
- 输出：`SessionSummary.projectName: String?`
- 输出：`SessionScanner.projectName(for:homeDirectory:) -> String?`

- [ ] **步骤一：添加失败测试**

```swift
func testHomeDirectoryDoesNotBecomeProjectName() {
    let home = URL(fileURLWithPath: "/Users/lele", isDirectory: true)

    XCTAssertNil(SessionScanner.projectName(for: "/Users/lele", homeDirectory: home))
    XCTAssertNil(SessionScanner.projectName(for: "/Users/lele/", homeDirectory: home))
    XCTAssertEqual(
        SessionScanner.projectName(
            for: "/Users/lele/Desktop/大丰数艺/Codex额度",
            homeDirectory: home
        ),
        "Codex额度"
    )
}
```

在 `UsageAggregatorTests` 中添加一个 `project: nil` 的会话，并断言其 Token 进入 `lifetimeTokens`，但 `projects` 不包含“lele”。

- [ ] **步骤二：运行测试并确认失败**

运行：

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/tmp/codex-monitor-clang-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/tmp/codex-monitor-swift-cache \
  swift test --disable-sandbox --filter 'JSONLDecoderTests|UsageAggregatorTests'
```

预期：因 `projectName` 尚非可选值且路径过滤接口不存在而失败。

- [ ] **步骤三：实现可选项目名和精确路径过滤**

```swift
struct SessionSummary: Equatable, Sendable {
    let date: Date
    let projectName: String?
    let totalTokens: Int
    let longestTaskDuration: TimeInterval
    let state: ProjectRunState
    let updatedAt: Date
    let weeklyUsedPercent: Double?
    let weeklyResetsAt: Date?
}
```

```swift
static func projectName(for cwd: String, homeDirectory: URL) -> String? {
    let directory = URL(fileURLWithPath: cwd, isDirectory: true).standardizedFileURL
    let home = homeDirectory.standardizedFileURL
    guard directory != home else { return nil }
    let name = directory.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty ? nil : name
}
```

`parseFile` 接收可测试的默认主目录参数，并通过上述接口生成项目名：

```swift
static func parseFile(
    _ url: URL,
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
) throws -> SessionSummary? {
    guard let timestamp, let cwd else {
        return nil
    }
    return SessionSummary(
        date: timestamp,
        projectName: projectName(for: cwd, homeDirectory: homeDirectory),
        totalTokens: tokens,
        longestTaskDuration: longestTaskDuration,
        state: state,
        updatedAt: updatedAt == .distantPast ? timestamp : updatedAt,
        weeklyUsedPercent: weeklyUsedPercent,
        weeklyResetsAt: weeklyResetsAt
    )
}
```

聚合项目时先排除无名称会话：

```swift
let namedSessions = sessions.compactMap { session in
    session.projectName.map { (name: $0, session: session) }
}
let groupedByProject = Dictionary(grouping: namedSessions, by: \.name)
```

- [ ] **步骤四：运行聚焦测试并确认通过**

运行与步骤二相同的测试命令。

预期：相关测试全部通过。

---

### 任务二：检测项目完成状态转换

**文件：**
- 新建：`Sources/CodexMonitor/Notifications/ProjectCompletionDetector.swift`
- 新建：`Tests/CodexMonitorTests/ProjectCompletionDetectorTests.swift`

**接口：**
- 输入：`[ProjectActivity]`
- 输出：`mutating func completedProjects(in:) -> [ProjectActivity]`

- [ ] **步骤一：添加失败测试**

```swift
func testOnlyRunningToCompletedProducesNotification() {
    var detector = ProjectCompletionDetector()
    XCTAssertTrue(detector.completedProjects(in: [project("甲", .running)]).isEmpty)
    XCTAssertEqual(
        detector.completedProjects(in: [project("甲", .completed)]).map(\.name),
        ["甲"]
    )
    XCTAssertTrue(detector.completedProjects(in: [project("甲", .completed)]).isEmpty)
}

func testInitialCompletedAndFailedProjectsDoNotProduceNotification() {
    var detector = ProjectCompletionDetector()
    XCTAssertTrue(detector.completedProjects(in: [
        project("历史完成", .completed),
        project("报错", .failed)
    ]).isEmpty)
}
```

- [ ] **步骤二：运行测试并确认失败**

运行：`swift test --disable-sandbox --filter ProjectCompletionDetectorTests`，并使用任务一相同的 Xcode 环境变量。

预期：因 `ProjectCompletionDetector` 不存在而失败。

- [ ] **步骤三：实现纯状态检测器**

```swift
struct ProjectCompletionDetector {
    private var previousStates: [String: ProjectRunState]?

    mutating func completedProjects(in projects: [ProjectActivity]) -> [ProjectActivity] {
        let currentStates = Dictionary(uniqueKeysWithValues: projects.map { ($0.name, $0.state) })
        defer { previousStates = currentStates }
        guard let previousStates else { return [] }
        return projects.filter {
            $0.state == .completed && previousStates[$0.name] == .running
        }
    }
}
```

- [ ] **步骤四：运行检测器测试并确认通过**

预期：首次完成、报错、重复完成均不产生结果，只有运行到完成产生一次结果。

---

### 任务三：接入 macOS 系统通知和默认音效

**文件：**
- 新建：`Sources/CodexMonitor/Notifications/ProjectCompletionNotifier.swift`
- 新建：`Tests/CodexMonitorTests/ProjectCompletionNotifierTests.swift`
- 修改：`Sources/CodexMonitor/App/AppDelegate.swift`

**接口：**
- 输出：`CompletionNotificationMessage.message(for:)`
- 输出：`ProjectCompletionNotifier.requestAuthorization()`
- 输出：`ProjectCompletionNotifier.notify(projectName:)`

- [ ] **步骤一：添加通知文案失败测试**

```swift
func testCompletionNotificationUsesExpectedChineseCopy() {
    XCTAssertEqual(
        CompletionNotificationMessage.message(for: "Codex额度"),
        CompletionNotificationMessage(
            title: "Codex 项目已完成",
            body: "Codex额度 已完成"
        )
    )
}
```

- [ ] **步骤二：运行测试并确认失败**

运行：`swift test --disable-sandbox --filter ProjectCompletionNotifierTests`，并使用任务一相同的 Xcode 环境变量。

预期：因通知文案和通知服务不存在而失败。

- [ ] **步骤三：实现通知文案与服务**

```swift
import UserNotifications

struct CompletionNotificationMessage: Equatable {
    let title: String
    let body: String

    static func message(for projectName: String) -> Self {
        Self(title: "Codex 项目已完成", body: "\(projectName) 已完成")
    }
}

final class ProjectCompletionNotifier: NSObject, UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notify(projectName: String) {
        let message = CompletionNotificationMessage.message(for: projectName)
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        center.add(UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        ))
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
```

- [ ] **步骤四：连接 AppDelegate**

在 `AppDelegate` 中持有 `AnyCancellable`、检测器和通知服务。启动时申请权限并订阅 `store.$snapshot`：

```swift
private let completionNotifier = ProjectCompletionNotifier()
private var completionDetector = ProjectCompletionDetector()
private var snapshotCancellable: AnyCancellable?

completionNotifier.requestAuthorization()
snapshotCancellable = store.$snapshot.sink { [weak self] snapshot in
    guard let self else { return }
    for project in completionDetector.completedProjects(in: snapshot.projects) {
        completionNotifier.notify(projectName: project.name)
    }
}
```

- [ ] **步骤五：运行完整测试**

运行：`swift test --disable-sandbox`，并使用任务一相同的 Xcode 环境变量。

预期：所有测试通过，零失败。

---

### 任务四：打包、验证并更新运行应用

**文件：**
- 生成：`dist/Codex Monitor.app`

- [ ] **步骤一：重新打包**

运行：`bash scripts/package-app.sh`

预期：生成签名后的应用包。

- [ ] **步骤二：验证签名**

运行：`codesign --verify --deep --strict --verbose=2 'dist/Codex Monitor.app'`

预期：应用在磁盘上有效并满足指定要求。

- [ ] **步骤三：重启登录启动任务**

结束旧的 `CodexMonitor` 进程，再运行：

```bash
launchctl kickstart gui/501/com.dafeng.codexmonitor.loginitem
```

验证 LaunchAgent 状态为 `running`，并且只有一个新进程。

- [ ] **步骤四：提交实现**

```bash
git add Sources Tests docs/superpowers/plans/2026-07-14-project-name-completion-notification.md
git commit -m "修复：过滤虚假项目并增加完成通知"
```
