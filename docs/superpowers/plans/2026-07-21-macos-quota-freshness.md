# macOS 周额度自动校准实施计划

> **面向执行代理：** 必须使用 `superpowers:executing-plans` 按任务逐项实施；每项代码修改都遵循测试驱动流程。

**目标：** 让 macOS 菜单栏始终读取最新周额度，并在文件事件遗漏或系统睡眠后自动恢复刷新。

**架构：** 扫描层为每条周额度保存额度事件自身时间，汇总层以该时间选择最新主 Codex 额度。应用层保留文件监听并增加 30 秒定时校准与系统唤醒刷新，所有入口继续复用 `MonitorStore` 的防抖、请求合并和增量扫描。

**技术栈：** Swift 6.2、SwiftUI、AppKit、Combine、XCTest、Swift Package Manager。

## 全局约束

- 所有文档和 Git 提交信息使用中文。
- 只修改 macOS 版本，不改变 Windows 数据行为。
- 自动校准间隔固定为 30 秒。
- 保留现有界面布局、菜单栏文案、通知、GitHub 页面和五页交互。
- 额度继续按 `100 - used_percent` 换算并限制在 0%–100%。
- 使用额度事件时间选择最新主 Codex 周额度；缺失事件时间时兼容回退到会话更新时间。

---

### 任务 1：按额度事件时间选择最新额度

**文件：**

- 修改：`Sources/CodexMonitor/Data/CodexJSONL.swift`
- 修改：`Sources/CodexMonitor/Data/SessionScanner.swift`
- 修改：`Sources/CodexMonitor/Data/UsageAggregator.swift`
- 测试：`Tests/CodexMonitorTests/JSONLDecoderTests.swift`
- 测试：`Tests/CodexMonitorTests/UsageAggregatorTests.swift`

**接口：**

- 输入：JSONL `token_count` 外层 `timestamp`、`rate_limits.limit_id` 和 7 天窗口 `used_percent`。
- 输出：`SessionSummary.weeklyQuotaUpdatedAt: Date?`，以及使用该时间生成的 `WeeklyQuota.remainingPercent`。

- [ ] **步骤 1：编写失败的扫描与汇总测试**

在 `JSONLDecoderTests` 的大文件额度测试中增加：

```swift
XCTAssertEqual(
    summary?.weeklyQuotaUpdatedAt,
    ISO8601DateFormatter().date(from: "2026-07-14T03:06:03Z")
)
```

在 `UsageAggregatorTests` 增加新额度覆盖旧额度的测试，并扩展测试辅助方法：

```swift
func testNewestQuotaEventWinsEvenWhenOlderSessionRemainsActive() {
    let now = date(2026, 7, 21, 12)
    let sessions = [
        summary(
            date: now,
            project: "旧会话",
            tokens: 100,
            state: .running,
            updatedAt: now,
            weeklyUsed: 16,
            weeklyLimitID: "codex",
            weeklyQuotaUpdatedAt: now.addingTimeInterval(-120)
        ),
        summary(
            date: now,
            project: "新额度",
            tokens: 100,
            state: .running,
            updatedAt: now.addingTimeInterval(-60),
            weeklyUsed: 2,
            weeklyLimitID: "codex",
            weeklyQuotaUpdatedAt: now.addingTimeInterval(-30)
        )
    ]

    let snapshot = UsageAggregator.makeSnapshot(
        sessions: sessions,
        now: now,
        calendar: utcCalendar
    )

    XCTAssertEqual(snapshot.weeklyQuota.remainingPercent, 98)
}
```

辅助方法增加参数并传入模型：

```swift
weeklyQuotaUpdatedAt: Date? = nil
```

- [ ] **步骤 2：运行定向测试并确认失败**

运行：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/tmp/codex-monitor-clang-cache \
SWIFT_MODULECACHE_PATH=/tmp/codex-monitor-swift-cache \
xcrun swift test --disable-sandbox \
  --filter 'JSONLDecoderTests/testSecondaryWeeklyWindowIsParsedFromLargeSessionFile|UsageAggregatorTests/testNewestQuotaEventWinsEvenWhenOlderSessionRemainsActive'
```

预期：编译或断言失败，因为 `weeklyQuotaUpdatedAt` 尚不存在。

- [ ] **步骤 3：实现最小的数据新鲜度修改**

在 `SessionSummary` 中增加字段，并在初始化器末尾提供兼容默认值：

```swift
let weeklyQuotaUpdatedAt: Date?

init(
    date: Date,
    projectName: String?,
    sessionID: String = "",
    agentNickname: String? = nil,
    sessionTitle: String? = nil,
    turnID: String? = nil,
    isTopLevel: Bool = true,
    totalTokens: Int,
    longestTaskDuration: TimeInterval,
    state: ProjectRunState,
    updatedAt: Date,
    weeklyUsedPercent: Double?,
    weeklyLimitID: String? = nil,
    weeklyResetsAt: Date?,
    weeklyQuotaUpdatedAt: Date? = nil
) {
    self.date = date
    self.projectName = projectName
    self.sessionID = sessionID
    self.agentNickname = agentNickname
    self.sessionTitle = sessionTitle
    self.turnID = turnID
    self.isTopLevel = isTopLevel
    self.totalTokens = totalTokens
    self.longestTaskDuration = longestTaskDuration
    self.state = state
    self.updatedAt = updatedAt
    self.weeklyUsedPercent = weeklyUsedPercent
    self.weeklyLimitID = weeklyLimitID
    self.weeklyResetsAt = weeklyResetsAt
    self.weeklyQuotaUpdatedAt = weeklyQuotaUpdatedAt
}
```

在 `SessionScanner.parseFile` 中保存额度事件时间：

```swift
var weeklyQuotaUpdatedAt: Date?

if let weeklyWindow = payload.rateLimits?.weeklyWindow {
    weeklyUsedPercent = weeklyWindow.usedPercent
    weeklyLimitID = payload.rateLimits?.limitID
    weeklyResetsAt = weeklyWindow.resetsAt.map(Date.init(timeIntervalSince1970:))
    weeklyQuotaUpdatedAt = envelope.timestamp.flatMap(parseTimestamp)
}
```

构造 `SessionSummary` 时传入：

```swift
weeklyResetsAt: weeklyResetsAt,
weeklyQuotaUpdatedAt: weeklyQuotaUpdatedAt
```

在 `UsageAggregator` 中使用额度事件时间，时间相同时以会话更新时间打破平局：

```swift
let newestQuota = (canonicalQuotaSessions.isEmpty ? quotaSessions : canonicalQuotaSessions)
    .max { lhs, rhs in
        let lhsQuotaTime = lhs.weeklyQuotaUpdatedAt ?? lhs.updatedAt
        let rhsQuotaTime = rhs.weeklyQuotaUpdatedAt ?? rhs.updatedAt
        if lhsQuotaTime != rhsQuotaTime {
            return lhsQuotaTime < rhsQuotaTime
        }
        return lhs.updatedAt < rhs.updatedAt
    }
```

- [ ] **步骤 4：运行定向测试并确认通过**

重复步骤 2 的命令。

预期：两个定向测试全部通过，`used_percent == 2` 得到剩余 98%。

- [ ] **步骤 5：提交额度新鲜度修改**

```bash
git add Sources/CodexMonitor/Data Tests/CodexMonitorTests/JSONLDecoderTests.swift Tests/CodexMonitorTests/UsageAggregatorTests.swift
git commit -m "修复：按额度事件时间读取最新数据"
```

---

### 任务 2：增加定时校准和睡眠唤醒刷新

**文件：**

- 修改：`Sources/CodexMonitor/App/AppDelegate.swift`
- 测试：`Tests/CodexMonitorTests/AppIntegrationTests.swift`

**接口：**

- 输入：30 秒定时事件、`NSWorkspace.didWakeNotification`。
- 输出：调用现有 `MonitorStore.requestRefresh()`，退出时取消定时订阅并移除唤醒观察者。

- [ ] **步骤 1：编写失败的应用接线测试**

在 `AppIntegrationTests` 增加源码契约测试：

```swift
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

    XCTAssertTrue(source.contains("Timer.publish(every: 30"))
    XCTAssertTrue(source.contains("NSWorkspace.didWakeNotification"))
    XCTAssertTrue(source.contains("periodicRefreshCancellable?.cancel()"))
    XCTAssertTrue(source.contains("removeObserver(wakeObserver)"))
}
```

- [ ] **步骤 2：运行测试并确认失败**

运行：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/tmp/codex-monitor-clang-cache \
SWIFT_MODULECACHE_PATH=/tmp/codex-monitor-swift-cache \
xcrun swift test --disable-sandbox \
  --filter AppIntegrationTests/testAppPeriodicallyRefreshesQuotaAndRefreshesAfterWake
```

预期：四个源码契约断言失败。

- [ ] **步骤 3：实现自动校准和唤醒刷新**

在 `AppDelegate` 增加生命周期状态：

```swift
private var periodicRefreshCancellable: AnyCancellable?
private var wakeObserver: NSObjectProtocol?
```

在应用完成启动后建立两个刷新入口：

```swift
periodicRefreshCancellable = Timer.publish(every: 30, on: .main, in: .common)
    .autoconnect()
    .sink { [weak store] _ in
        store?.requestRefresh()
    }

wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didWakeNotification,
    object: nil,
    queue: .main
) { [weak store] _ in
    Task { @MainActor in
        store?.requestRefresh()
    }
}
```

在 `applicationWillTerminate` 中释放资源：

```swift
periodicRefreshCancellable?.cancel()
if let wakeObserver {
    NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
}
```

- [ ] **步骤 4：运行定向测试并确认通过**

重复步骤 2 的命令。

预期：应用接线测试通过。

- [ ] **步骤 5：提交自动刷新修改**

```bash
git add Sources/CodexMonitor/App/AppDelegate.swift Tests/CodexMonitorTests/AppIntegrationTests.swift
git commit -m "修复：增加周额度自动校准刷新"
```

---

### 任务 3：完整验证、版本更新与打包

**文件：**

- 修改：`Resources/Info.plist`
- 修改：`Tests/CodexMonitorTests/AppIntegrationTests.swift`
- 生成：`dist/Codex Monitor.app`

**接口：**

- 输入：通过全部测试的源代码。
- 输出：版本 `0.1.10`、构建号 `11` 的已签名 macOS 应用。

- [ ] **步骤 1：运行完整测试套件**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/tmp/codex-monitor-clang-cache \
SWIFT_MODULECACHE_PATH=/tmp/codex-monitor-swift-cache \
xcrun swift test --disable-sandbox
```

预期：全部测试通过且无失败。

- [ ] **步骤 2：先更新版本测试并确认失败**

将 `AppIntegrationTests.testAppMetadataDeclaresPackagedIcon` 的期望值更新为：

```swift
XCTAssertEqual(plist["CFBundleShortVersionString"] as? String, "0.1.10")
XCTAssertEqual(plist["CFBundleVersion"] as? String, "11")
```

运行：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/tmp/codex-monitor-clang-cache \
SWIFT_MODULECACHE_PATH=/tmp/codex-monitor-swift-cache \
xcrun swift test --disable-sandbox --filter AppIntegrationTests/testAppMetadataDeclaresPackagedIcon
```

预期：版本断言失败，实际仍为 `0.1.9 (10)`。

- [ ] **步骤 3：更新应用版本**

在 `Resources/Info.plist` 中更新：

```xml
<key>CFBundleShortVersionString</key>
<string>0.1.10</string>
<key>CFBundleVersion</key>
<string>11</string>
```

- [ ] **步骤 4：重新运行完整测试并打包**

先重复步骤 1 的完整测试命令，确认全部通过，然后运行：

```bash
bash scripts/package-app.sh
```

预期：Release 构建成功并生成 `dist/Codex Monitor.app`。

- [ ] **步骤 5：验证最终产物**

```bash
test -x 'dist/Codex Monitor.app/Contents/MacOS/CodexMonitor'
plutil -p 'dist/Codex Monitor.app/Contents/Info.plist' | rg '0.1.10|11'
codesign --verify --deep --strict 'dist/Codex Monitor.app'
```

预期：可执行文件存在，版本为 `0.1.10 (11)`，签名验证返回成功。

- [ ] **步骤 6：提交版本与计划**

```bash
git add Resources/Info.plist Tests/CodexMonitorTests/AppIntegrationTests.swift docs/superpowers/plans/2026-07-21-macos-quota-freshness.md
git commit -m "发布：更新周额度校准版本"
```
