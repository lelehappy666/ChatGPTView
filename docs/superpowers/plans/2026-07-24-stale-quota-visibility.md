# macOS 过期周额度隐藏与自动恢复实施计划

> **面向执行代理：** 必须使用 `superpowers:executing-plans` 按任务逐项实施；每个生产代码修改都先有失败测试。

**目标：** 超过5分钟没有新额度事件时隐藏旧百分比，并在30秒自动刷新或新事件到达后自动恢复正确值。

**架构：** 聚合模型携带选中额度事件的时间，纯函数策略根据当前时间判断额度是否可展示。菜单栏复用现有4秒时间脉冲，周额度页增加30秒时间脉冲；两个界面都只读取策略过滤后的百分比，底层原始快照继续保留。

**技术栈：** Swift 6.2、SwiftUI、Combine、AppKit、XCTest、Swift Package Manager。

## 全局约束

- 所有文档和Git提交信息使用中文。
- 只修改macOS版本，不改变Windows行为。
- 新鲜期限固定为300秒，未来时间容差固定为60秒。
- 应用继续每30秒自动刷新本地数据。
- 过期时菜单栏显示 `Week —`，周额度页显示 `—`和`等待 Codex 更新`。
- 新额度事件进入快照后自动恢复百分比，无需重启。
- 不调用未公开接口，不读取或保存Codex登录凭据。
- 版本更新为 `0.1.11 (12)`。

---

### 任务1：建立额度事件时间与新鲜度策略

**文件：**

- 修改：`Sources/CodexMonitor/Domain/MonitorModels.swift`
- 修改：`Sources/CodexMonitor/Data/UsageAggregator.swift`
- 测试：`Tests/CodexMonitorTests/MonitorModelsTests.swift`
- 测试：`Tests/CodexMonitorTests/UsageAggregatorTests.swift`

**接口：**

- 输入：`WeeklyQuota.remainingPercent`、`WeeklyQuota.updatedAt`和当前时间。
- 输出：`QuotaFreshnessPolicy.visibleRemainingPercent(for:at:) -> Double?`。

- [ ] **步骤1：编写新鲜度边界失败测试**

在 `MonitorModelsTests` 增加：

```swift
func testQuotaFreshnessShowsOnlyRecentValues() {
    let eventTime = Date(timeIntervalSince1970: 1_000)
    let quota = WeeklyQuota(
        remainingPercent: 34,
        resetsAt: nil,
        updatedAt: eventTime
    )

    XCTAssertEqual(
        QuotaFreshnessPolicy.visibleRemainingPercent(
            for: quota,
            at: eventTime.addingTimeInterval(299)
        ),
        34
    )
    XCTAssertEqual(
        QuotaFreshnessPolicy.visibleRemainingPercent(
            for: quota,
            at: eventTime.addingTimeInterval(300)
        ),
        34
    )
    XCTAssertNil(
        QuotaFreshnessPolicy.visibleRemainingPercent(
            for: quota,
            at: eventTime.addingTimeInterval(301)
        )
    )
}

func testQuotaFreshnessRejectsMissingTimestampAndLargeFutureSkew() {
    let now = Date(timeIntervalSince1970: 2_000)
    XCTAssertNil(
        QuotaFreshnessPolicy.visibleRemainingPercent(
            for: WeeklyQuota(remainingPercent: 34, resetsAt: nil),
            at: now
        )
    )
    XCTAssertEqual(
        QuotaFreshnessPolicy.visibleRemainingPercent(
            for: WeeklyQuota(
                remainingPercent: 34,
                resetsAt: nil,
                updatedAt: now.addingTimeInterval(60)
            ),
            at: now
        ),
        34
    )
    XCTAssertNil(
        QuotaFreshnessPolicy.visibleRemainingPercent(
            for: WeeklyQuota(
                remainingPercent: 34,
                resetsAt: nil,
                updatedAt: now.addingTimeInterval(61)
            ),
            at: now
        )
    )
}

func testQuotaFreshnessRecoversWhenNewEventArrives() {
    let now = Date(timeIntervalSince1970: 3_000)
    let stale = WeeklyQuota(
        remainingPercent: 44,
        resetsAt: nil,
        updatedAt: now.addingTimeInterval(-301)
    )
    let refreshed = WeeklyQuota(
        remainingPercent: 34,
        resetsAt: nil,
        updatedAt: now
    )

    XCTAssertNil(
        QuotaFreshnessPolicy.visibleRemainingPercent(for: stale, at: now)
    )
    XCTAssertEqual(
        QuotaFreshnessPolicy.visibleRemainingPercent(for: refreshed, at: now),
        34
    )
}
```

在 `UsageAggregatorTests.testNewestQuotaEventWinsEvenWhenOlderSessionRemainsActive` 增加：

```swift
XCTAssertEqual(
    snapshot.weeklyQuota.updatedAt,
    now.addingTimeInterval(-30)
)
```

- [ ] **步骤2：运行定向测试并确认失败**

运行：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/tmp/codex-monitor-clang-cache \
SWIFT_MODULECACHE_PATH=/tmp/codex-monitor-swift-cache \
xcrun swift test --disable-sandbox \
  --filter 'MonitorModelsTests/testQuotaFreshness|UsageAggregatorTests/testNewestQuotaEventWinsEvenWhenOlderSessionRemainsActive'
```

预期：编译失败，因为 `WeeklyQuota.updatedAt` 和 `QuotaFreshnessPolicy` 尚不存在。

- [ ] **步骤3：实现周额度时间与纯函数策略**

将 `WeeklyQuota` 改为：

```swift
struct WeeklyQuota: Equatable, Sendable {
    let remainingPercent: Double?
    let resetsAt: Date?
    let updatedAt: Date?

    init(
        remainingPercent: Double?,
        resetsAt: Date?,
        updatedAt: Date? = nil
    ) {
        self.remainingPercent = remainingPercent
        self.resetsAt = resetsAt
        self.updatedAt = updatedAt
    }
}

enum QuotaFreshnessPolicy {
    static let freshDuration: TimeInterval = 300
    static let futureTolerance: TimeInterval = 60

    static func visibleRemainingPercent(
        for quota: WeeklyQuota,
        at now: Date = .now
    ) -> Double? {
        guard let remainingPercent = quota.remainingPercent,
              let updatedAt = quota.updatedAt else {
            return nil
        }
        let age = now.timeIntervalSince(updatedAt)
        guard age >= -futureTolerance,
              age <= freshDuration else {
            return nil
        }
        return remainingPercent
    }
}
```

在 `UsageAggregator.makeSnapshot` 构造周额度时加入：

```swift
weeklyQuota: WeeklyQuota(
    remainingPercent: remainingPercent,
    resetsAt: newestQuota?.weeklyResetsAt,
    updatedAt: newestQuota?.weeklyQuotaUpdatedAt
)
```

- [ ] **步骤4：运行定向测试并确认通过**

重复步骤2的命令。

预期：新鲜度边界、未来容差和聚合时间测试全部通过。

- [ ] **步骤5：提交模型与策略**

```bash
git add Sources/CodexMonitor/Domain/MonitorModels.swift Sources/CodexMonitor/Data/UsageAggregator.swift Tests/CodexMonitorTests/MonitorModelsTests.swift Tests/CodexMonitorTests/UsageAggregatorTests.swift
git commit -m "修复：增加周额度新鲜度判断"
```

---

### 任务2：隐藏过期百分比并自动恢复显示

**文件：**

- 修改：`Sources/CodexMonitor/MenuBar/MenuBarContentView.swift`
- 修改：`Sources/CodexMonitor/Notch/WeeklyQuotaPage.swift`
- 测试：`Tests/CodexMonitorTests/AppIntegrationTests.swift`

**接口：**

- 输入：任务1提供的 `QuotaFreshnessPolicy.visibleRemainingPercent(for:at:)`。
- 输出：新鲜时显示百分比，过期时菜单栏显示 `Week —`，页面显示 `等待 Codex 更新`。

- [ ] **步骤1：编写界面接线失败测试**

在 `AppIntegrationTests` 增加：

```swift
func testQuotaViewsHideStalePercentageAndKeepTimeMoving() throws {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let menuSource = try String(
        contentsOf: root.appendingPathComponent(
            "Sources/CodexMonitor/MenuBar/MenuBarContentView.swift"
        ),
        encoding: .utf8
    )
    let pageSource = try String(
        contentsOf: root.appendingPathComponent(
            "Sources/CodexMonitor/Notch/WeeklyQuotaPage.swift"
        ),
        encoding: .utf8
    )

    XCTAssertTrue(menuSource.contains("QuotaFreshnessPolicy.visibleRemainingPercent"))
    XCTAssertTrue(menuSource.contains("@State private var now = Date.now"))
    XCTAssertTrue(pageSource.contains("QuotaFreshnessPolicy.visibleRemainingPercent"))
    XCTAssertTrue(pageSource.contains("Timer.publish("))
    XCTAssertTrue(pageSource.contains("every: 30"))
    XCTAssertTrue(pageSource.contains("等待 Codex 更新"))
}
```

- [ ] **步骤2：运行界面接线测试并确认失败**

运行：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/tmp/codex-monitor-clang-cache \
SWIFT_MODULECACHE_PATH=/tmp/codex-monitor-swift-cache \
xcrun swift test --disable-sandbox \
  --filter AppIntegrationTests/testQuotaViewsHideStalePercentageAndKeepTimeMoving
```

预期：六个断言失败，因为两个界面仍直接读取原始百分比。

- [ ] **步骤3：修改菜单栏使用新鲜度策略**

在 `MenuBarContentView` 增加当前时间状态：

```swift
@State private var now = Date.now
```

在现有4秒定时器回调开头更新时间：

```swift
.onReceive(timer) { now in
    self.now = now
    ticker.projects = store.snapshot.projects.visibleForMenu(at: now)
    withAnimation(.easeInOut(duration: 0.28)) {
        ticker.advance()
    }
}
```

将 `weeklyText` 改为：

```swift
private var weeklyText: String {
    guard let remaining = QuotaFreshnessPolicy.visibleRemainingPercent(
        for: store.snapshot.weeklyQuota,
        at: now
    ) else {
        return "Week —"
    }
    return "Week \(Int(remaining.rounded()))%"
}
```

- [ ] **步骤4：修改周额度页使用30秒时间脉冲**

在 `WeeklyQuotaPage.swift` 顶部加入：

```swift
import Combine
import SwiftUI
```

在视图中增加：

```swift
@State private var now = Date.now
private let freshnessTimer = Timer.publish(
    every: 30,
    on: .main,
    in: .common
).autoconnect()

private var remaining: Double? {
    QuotaFreshnessPolicy.visibleRemainingPercent(
        for: snapshot.weeklyQuota,
        at: now
    )
}
```

在根视图末尾增加：

```swift
.onReceive(freshnessTimer) { now in
    self.now = now
}
```

百分号只在存在新鲜百分比时显示：

```swift
if remaining != nil {
    Text("%")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.secondary)
}
```

将同步状态改为：

```swift
private var syncText: String {
    if snapshot.weeklyQuota.remainingPercent == nil {
        return "暂不可用"
    }
    return remaining == nil ? "等待 Codex 更新" : "● 已同步"
}
```

`used`继续由过滤后的 `remaining`计算，因此过期时自动为0。

- [ ] **步骤5：运行界面接线测试并确认通过**

重复步骤2的命令。

预期：界面接线测试通过。

- [ ] **步骤6：提交界面行为**

```bash
git add Sources/CodexMonitor/MenuBar/MenuBarContentView.swift Sources/CodexMonitor/Notch/WeeklyQuotaPage.swift Tests/CodexMonitorTests/AppIntegrationTests.swift
git commit -m "修复：隐藏过期额度并自动恢复显示"
```

---

### 任务3：版本升级、完整验证与打包

**文件：**

- 修改：`Resources/Info.plist`
- 修改：`Tests/CodexMonitorTests/AppIntegrationTests.swift`
- 生成：`dist/Codex Monitor.app`

**接口：**

- 输入：通过任务1和任务2测试的源代码。
- 输出：版本 `0.1.11 (12)` 的签名macOS应用。

- [ ] **步骤1：先修改版本期望并确认失败**

在 `AppIntegrationTests.testAppMetadataDeclaresPackagedIcon` 中改为：

```swift
XCTAssertEqual(plist["CFBundleShortVersionString"] as? String, "0.1.11")
XCTAssertEqual(plist["CFBundleVersion"] as? String, "12")
```

运行：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/tmp/codex-monitor-clang-cache \
SWIFT_MODULECACHE_PATH=/tmp/codex-monitor-swift-cache \
xcrun swift test --disable-sandbox \
  --filter AppIntegrationTests/testAppMetadataDeclaresPackagedIcon
```

预期：断言失败，实际版本仍为 `0.1.10 (11)`。

- [ ] **步骤2：更新应用版本**

在 `Resources/Info.plist` 中改为：

```xml
<key>CFBundleShortVersionString</key>
<string>0.1.11</string>
<key>CFBundleVersion</key>
<string>12</string>
```

- [ ] **步骤3：运行完整测试**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/tmp/codex-monitor-clang-cache \
SWIFT_MODULECACHE_PATH=/tmp/codex-monitor-swift-cache \
xcrun swift test --disable-sandbox
```

预期：全部测试通过且无失败。

- [ ] **步骤4：重新打包**

```bash
bash scripts/package-app.sh
```

预期：Release构建成功并生成 `dist/Codex Monitor.app`。

- [ ] **步骤5：验证版本、可执行文件和签名**

```bash
test -x 'dist/Codex Monitor.app/Contents/MacOS/CodexMonitor'
plutil -p 'dist/Codex Monitor.app/Contents/Info.plist' | rg '0.1.11|12'
codesign --verify --deep --strict --verbose=2 'dist/Codex Monitor.app'
```

预期：版本为 `0.1.11 (12)`，可执行文件存在，签名满足指定要求。

- [ ] **步骤6：提交版本与计划**

```bash
git add Resources/Info.plist Tests/CodexMonitorTests/AppIntegrationTests.swift docs/superpowers/plans/2026-07-24-stale-quota-visibility.md
git commit -m "发布：更新过期额度隐藏版本"
```
