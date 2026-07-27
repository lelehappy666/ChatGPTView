# 菜单栏悬停打开与数字滚动动画实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 为 macOS 菜单栏入口增加防误触悬停打开，并让下拉数据面板中的全部动态指标在每次打开和数据刷新时播放数字滚动动画。

**架构：** 用纯 Swift 状态协调器统一菜单栏入口与面板的悬停状态，由 `MenuBarController` 执行延迟打开和关闭任务。用共享展示周期对象驱动可复用的 SwiftUI 数字文本组件，各数据区只提供最终文字与零值文字，不自行管理动画。

**技术栈：** Swift 6.2、SwiftUI、AppKit、Combine、XCTest、Swift Package Manager。

## 全局约束

- 直接在 `main` 分支开发。
- 仅修改 macOS 菜单栏下拉面板，不修改刘海分页和 Windows 端。
- 保持现有菜单面板布局、配色、字号和内容顺序不变。
- 菜单入口悬停 120 毫秒后打开。
- 入口到面板保留 350 毫秒过渡时间，离开面板后延迟 300 毫秒关闭。
- 每次打开从零滚到当前值，刷新后从旧值滚到新值。
- macOS 开启“减少动态效果”时直接显示最终值。
- 版本更新为 `0.1.17 (18)`。

---

### 任务一：统一菜单栏入口与面板的悬停生命周期

**文件：**

- 新建：`Sources/CodexMonitor/MenuBar/MenuHoverCoordinator.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuBarController.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuBarContentView.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuDashboardView.swift`
- 新建：`Tests/CodexMonitorTests/MenuHoverCoordinatorTests.swift`

**接口：**

- 产生：`MenuHoverCoordinator.statusHoverChanged(isInside:isPopoverShown:) -> [MenuHoverAction]`
- 产生：`MenuHoverCoordinator.panelHoverChanged(isInside:isPopoverShown:) -> [MenuHoverAction]`
- 产生：`MenuHoverCoordinator.popoverDidShow()` 与 `popoverDidClose()`
- 产生：`MenuHoverAction.scheduleOpen`、`cancelOpen`、`scheduleClose(delay:)`、`cancelClose`
- 消费：`MenuBarController` 把 SwiftUI 上报的状态转换成可取消的 `Task`。

- [ ] **步骤 1：编写失败的悬停协调器测试**

```swift
func testStatusHoverSchedulesOpenAndCancelsPendingClose() {
    var coordinator = MenuHoverCoordinator()
    XCTAssertEqual(
        coordinator.statusHoverChanged(isInside: true, isPopoverShown: false),
        [.cancelClose, .scheduleOpen]
    )
}

func testLeavingStatusBeforeOpenCancelsOpen() {
    var coordinator = MenuHoverCoordinator()
    _ = coordinator.statusHoverChanged(isInside: true, isPopoverShown: false)
    XCTAssertEqual(
        coordinator.statusHoverChanged(isInside: false, isPopoverShown: false),
        [.cancelOpen]
    )
}

func testMovingFromStatusToPanelCancelsBridgeClose() {
    var coordinator = MenuHoverCoordinator()
    _ = coordinator.statusHoverChanged(isInside: true, isPopoverShown: true)
    coordinator.popoverDidShow()
    XCTAssertEqual(
        coordinator.statusHoverChanged(isInside: false, isPopoverShown: true),
        [.cancelOpen, .scheduleClose(delay: .statusToPanel)]
    )
    XCTAssertEqual(
        coordinator.panelHoverChanged(isInside: true, isPopoverShown: true),
        [.cancelClose]
    )
}

func testInitialPanelOutsideEventDoesNotCloseBeforeEntry() {
    var coordinator = MenuHoverCoordinator()
    coordinator.popoverDidShow()
    XCTAssertEqual(
        coordinator.panelHoverChanged(isInside: false, isPopoverShown: true),
        []
    )
}

func testLeavingEnteredPanelSchedulesPanelClose() {
    var coordinator = MenuHoverCoordinator()
    coordinator.popoverDidShow()
    _ = coordinator.panelHoverChanged(isInside: true, isPopoverShown: true)
    XCTAssertEqual(
        coordinator.panelHoverChanged(isInside: false, isPopoverShown: true),
        [.scheduleClose(delay: .panelExit)]
    )
}
```

- [ ] **步骤 2：运行测试并确认失败**

运行：

```bash
swift test --filter MenuHoverCoordinatorTests
```

预期：因 `MenuHoverCoordinator`、`MenuHoverAction` 和 `MenuHoverDelay` 尚未定义而编译失败。

- [ ] **步骤 3：实现纯状态协调器**

```swift
enum MenuHoverDelay: Equatable {
    case statusToPanel
    case panelExit

    var nanoseconds: UInt64 {
        switch self {
        case .statusToPanel: 350_000_000
        case .panelExit: 300_000_000
        }
    }
}

enum MenuHoverAction: Equatable {
    case scheduleOpen
    case cancelOpen
    case scheduleClose(delay: MenuHoverDelay)
    case cancelClose
}

struct MenuHoverCoordinator {
    private(set) var isStatusHovered = false
    private(set) var isPanelHovered = false
    private(set) var hasPanelEntered = false

    mutating func statusHoverChanged(
        isInside: Bool,
        isPopoverShown: Bool
    ) -> [MenuHoverAction]

    mutating func panelHoverChanged(
        isInside: Bool,
        isPopoverShown: Bool
    ) -> [MenuHoverAction]

    mutating func popoverDidShow()
    mutating func popoverDidClose()
}
```

协调器忽略面板首次进入前的 `false` 事件，避免面板刚出现就关闭。入口进入时取消关闭并在面板未显示时安排打开；入口离开时取消打开，并在面板显示且尚未进入面板时安排 350 毫秒桥接关闭；面板进入取消关闭，面板离开且入口不在悬停时安排 300 毫秒关闭。

- [ ] **步骤 4：运行协调器测试并确认通过**

运行：

```bash
swift test --filter MenuHoverCoordinatorTests
```

预期：新增测试全部通过。

- [ ] **步骤 5：把入口与面板悬停事件接入控制器**

`MenuBarContentView` 新增：

```swift
let onHoverChanged: (Bool) -> Void

// 根 HStack
.contentShape(Rectangle())
.onHover(perform: onHoverChanged)
```

`MenuDashboardView` 新增：

```swift
let onHoverChanged: (Bool) -> Void

// 根视图
.onHover(perform: onHoverChanged)
```

删除 `MenuDashboardView` 内部的 `MenuPopoverHoverState` 与 `autoCloseTask`。`MenuBarController` 新增协调器、打开任务和关闭任务；悬停动作统一交给：

```swift
private func perform(_ actions: [MenuHoverAction])
private func showPopover()
private func closePopover()
```

打开任务等待 `120_000_000` 纳秒。点击继续立即调用统一的 `showPopover()` 或 `closePopover()`，并先取消所有悬停任务。`stop()`、`popoverDidClose(_:)` 同样取消遗留任务。

- [ ] **步骤 6：运行菜单相关测试并提交**

运行：

```bash
swift test --filter MenuHoverCoordinatorTests
swift test --filter MenuDashboardCompositionTests
swift test --filter AppIntegrationTests
```

预期：全部通过。

提交：

```bash
git add Sources/CodexMonitor/MenuBar/MenuHoverCoordinator.swift \
  Sources/CodexMonitor/MenuBar/MenuBarController.swift \
  Sources/CodexMonitor/MenuBar/MenuBarContentView.swift \
  Sources/CodexMonitor/MenuBar/MenuDashboardView.swift \
  Tests/CodexMonitorTests/MenuHoverCoordinatorTests.swift
git commit -m "功能：菜单栏悬停打开数据面板"
```

---

### 任务二：建立可重播的统一数字滚动组件

**文件：**

- 新建：`Sources/CodexMonitor/MenuBar/MenuRollingNumberText.swift`
- 新建：`Tests/CodexMonitorTests/MenuRollingNumberTests.swift`

**接口：**

- 产生：`@MainActor final class MenuNumberAnimationContext: ObservableObject`
- 产生：`MenuNumberAnimationContext.beginPresentation()`
- 产生：`MenuNumberAnimationPlan.initialText(targetText:zeroText:reduceMotion:)`
- 产生：`MenuRollingNumberText(targetText:zeroText:)`
- 消费：任务三的所有菜单数据区。

- [ ] **步骤 1：编写失败的动画状态测试**

```swift
@MainActor
func testPresentationCycleIncrementsForEveryOpen() {
    let context = MenuNumberAnimationContext()
    XCTAssertEqual(context.cycle, 0)
    context.beginPresentation()
    context.beginPresentation()
    XCTAssertEqual(context.cycle, 2)
}

func testAnimatedPresentationStartsAtZeroText() {
    XCTAssertEqual(
        MenuNumberAnimationPlan.initialText(
            targetText: "85%",
            zeroText: "0%",
            reduceMotion: false
        ),
        "0%"
    )
}

func testReducedMotionStartsAtFinalText() {
    XCTAssertEqual(
        MenuNumberAnimationPlan.initialText(
            targetText: "85%",
            zeroText: "0%",
            reduceMotion: true
        ),
        "85%"
    )
}
```

- [ ] **步骤 2：运行测试并确认失败**

运行：

```bash
swift test --filter MenuRollingNumberTests
```

预期：因动画上下文、动画计划和数字组件尚未定义而编译失败。

- [ ] **步骤 3：实现动画上下文与数字组件**

```swift
@MainActor
final class MenuNumberAnimationContext: ObservableObject {
    @Published private(set) var cycle = 0

    func beginPresentation() {
        cycle &+= 1
    }
}

enum MenuNumberAnimationPlan {
    static func initialText(
        targetText: String,
        zeroText: String,
        reduceMotion: Bool
    ) -> String {
        reduceMotion ? targetText : zeroText
    }
}
```

`MenuRollingNumberText` 使用 `@EnvironmentObject` 读取周期、使用 `@Environment(\.accessibilityReduceMotion)` 读取辅助功能设置，并维护当前显示文字。出现或周期变化时先无动画设置零值，下一次主线程更新用约 450 毫秒的缓出动画切换到目标值；目标值变化时从当前值动画到新值。使用：

```swift
.contentTransition(.numericText())
.accessibilityLabel(targetText)
```

占位符 `—` 直接显示，不执行零值动画；组件消失时取消待执行任务。

- [ ] **步骤 4：运行组件测试并提交**

运行：

```bash
swift test --filter MenuRollingNumberTests
```

预期：全部通过。

提交：

```bash
git add Sources/CodexMonitor/MenuBar/MenuRollingNumberText.swift \
  Tests/CodexMonitorTests/MenuRollingNumberTests.swift
git commit -m "功能：新增菜单数字滚动组件"
```

---

### 任务三：接入面板全部动态指标

**文件：**

- 修改：`Sources/CodexMonitor/MenuBar/MenuBarController.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuDashboardView.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuWeeklyQuotaSection.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuDailyActivitySection.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuProjectAnalyticsSection.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuStatisticsSection.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuGitHubActivitySection.swift`
- 修改：`Tests/CodexMonitorTests/AppIntegrationTests.swift`

**接口：**

- 消费：`MenuNumberAnimationContext` 与 `MenuRollingNumberText`。
- 产生：每个下拉面板展示周期和每次数值更新对应的数字滚动。

- [ ] **步骤 1：编写失败的面板接入测试**

在 `AppIntegrationTests` 中读取菜单数据区源码，验证以下内容：

```swift
XCTAssertTrue(controller.contains("numberAnimationContext.beginPresentation()"))
XCTAssertTrue(dashboard.contains(".environmentObject(numberAnimationContext)"))
XCTAssertTrue(weekly.contains("MenuRollingNumberText"))
XCTAssertTrue(daily.contains("MenuRollingNumberText"))
XCTAssertTrue(project.contains("MenuRollingNumberText"))
XCTAssertTrue(statistics.contains("MenuRollingNumberText"))
XCTAssertTrue(github.contains("MenuRollingNumberText"))
```

- [ ] **步骤 2：运行测试并确认失败**

运行：

```bash
swift test --filter AppIntegrationTests
```

预期：因为控制器尚未触发展示周期、数据区尚未使用统一组件而失败。

- [ ] **步骤 3：把动画上下文传入面板**

`MenuBarController` 持有一个 `MenuNumberAnimationContext`，传给 `MenuDashboardView`。统一展示方法在调用 `popover.show` 前执行：

```swift
numberAnimationContext.beginPresentation()
```

`MenuDashboardView` 接收并注入：

```swift
.environmentObject(numberAnimationContext)
```

- [ ] **步骤 4：替换所有动态指标文本**

使用 `MenuRollingNumberText` 替换：

- 周额度：剩余额度、已用比例、重置天数与小时。
- 每日活动：今日 Token、会话、平均值、连续使用天数。
- 项目分析：七天 Token 总量、排名项目 Token 数。
- 统计总览：累计 Token、峰值 Token、最长任务时长、当前与最长连续天数。
- GitHub 活跃：总贡献数。

每个位置提供与格式匹配的零值。静态筛选、日期、星期、仓库更新时间和悬停说明保持 `Text`。

- [ ] **步骤 5：运行面板测试并提交**

运行：

```bash
swift test --filter AppIntegrationTests
swift test --filter MenuDashboardCompositionTests
swift test --filter MenuPopoverLayoutTests
```

预期：全部通过，面板布局契约未变化。

提交：

```bash
git add Sources/CodexMonitor/MenuBar/MenuBarController.swift \
  Sources/CodexMonitor/MenuBar/MenuDashboardView.swift \
  Sources/CodexMonitor/MenuBar/MenuWeeklyQuotaSection.swift \
  Sources/CodexMonitor/MenuBar/MenuDailyActivitySection.swift \
  Sources/CodexMonitor/MenuBar/MenuProjectAnalyticsSection.swift \
  Sources/CodexMonitor/MenuBar/MenuStatisticsSection.swift \
  Sources/CodexMonitor/MenuBar/MenuGitHubActivitySection.swift \
  Tests/CodexMonitorTests/AppIntegrationTests.swift
git commit -m "界面：为菜单数据增加数字滚动"
```

---

### 任务四：更新版本并生成测试包

**文件：**

- 修改：`Resources/Info.plist`
- 修改：`Tests/CodexMonitorTests/AppIntegrationTests.swift`
- 生成：`dist/Codex Monitor.app`

**接口：**

- 消费：前三个任务完成的源码和测试。
- 产生：版本为 `0.1.17 (18)` 的 macOS 应用包。

- [ ] **步骤 1：先把版本测试更新为新版本**

```swift
XCTAssertEqual(plist["CFBundleShortVersionString"] as? String, "0.1.17")
XCTAssertEqual(plist["CFBundleVersion"] as? String, "18")
```

- [ ] **步骤 2：运行版本测试并确认失败**

运行：

```bash
swift test --filter AppIntegrationTests/testAppIdentityAndVersion
```

预期：当前 `0.1.16 (17)` 与新期望不一致。

- [ ] **步骤 3：更新应用版本**

将 `Resources/Info.plist` 更新为：

```xml
<key>CFBundleShortVersionString</key>
<string>0.1.17</string>
<key>CFBundleVersion</key>
<string>18</string>
```

- [ ] **步骤 4：运行完整验证**

运行：

```bash
swift test
git diff --check
```

预期：全部测试通过，补丁无空白错误。

- [ ] **步骤 5：提交版本变更**

```bash
git add Resources/Info.plist Tests/CodexMonitorTests/AppIntegrationTests.swift
git commit -m "构建：更新菜单悬停与数字动画版本"
```

- [ ] **步骤 6：打包并核对产物**

运行：

```bash
bash scripts/package-app.sh
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
  "dist/Codex Monitor.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" \
  "dist/Codex Monitor.app/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "dist/Codex Monitor.app"
```

预期：生成 `dist/Codex Monitor.app`，版本为 `0.1.17 (18)`，签名验证通过。
