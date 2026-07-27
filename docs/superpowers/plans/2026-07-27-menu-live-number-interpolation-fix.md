# 菜单实时数字滚动修复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 把菜单动态指标从字符串切换改为真实数值逐帧插值，确保每日活动、统计总览、GitHub 贡献及其他指标每次打开都能从零滚动到实时数据。

**架构：** 用 `MenuNumberFormat` 统一原始数值到显示文字的格式化，用遵循 `Animatable` 的数字视图接收 SwiftUI 每一帧的中间 `Double`。`MenuRollingNumberText` 只管理展示周期、零值停留、目标更新和任务取消，各区块改为传递原始数值。

**技术栈：** Swift 6.2、SwiftUI、Combine、XCTest、Swift Package Manager。

## 全局约束

- 直接在 `main` 分支开发。
- 每次面板打开后从零开始，零值至少保留约 60 毫秒。
- 数字插值时长保持 1.2 秒，柱状图保持 1.0 秒。
- 刷新时从当前显示值过渡到最新实时值。
- “减少动态效果”开启时直接显示最终值。
- 静态筛选、日期、月份、仓库更新时间和悬停说明不动画。
- 不修改菜单布局、配色、字号、尺寸和悬停开关逻辑。
- 版本更新为 `0.1.19 (20)`。

---

### 任务一：建立真实数值格式与可插值文本

**文件：**

- 修改：`Sources/CodexMonitor/MenuBar/MenuRollingNumberText.swift`
- 修改：`Tests/CodexMonitorTests/MenuRollingNumberTests.swift`

**接口：**

- 产生：`enum MenuNumberFormat`
- 产生：`MenuNumberFormat.string(for value: Double) -> String`
- 产生：`struct MenuInterpolatingNumberText: View, Animatable`
- 产生：`MenuRollingNumberText(value: Double?, format: MenuNumberFormat)`

- [ ] **步骤 1：编写失败的格式和插值测试**

```swift
func testNumberFormatsRenderIntermediateRealtimeValues() {
    XCTAssertEqual(MenuNumberFormat.integer.string(for: 44), "44")
    XCTAssertEqual(MenuNumberFormat.percentage.string(for: 66), "66%")
    XCTAssertEqual(MenuNumberFormat.tokens.string(for: 50_000), "5 万")
    XCTAssertEqual(MenuNumberFormat.days.string(for: 3), "3 天")
    XCTAssertEqual(
        MenuNumberFormat.duration.string(for: 6_900),
        "1 小时 55 分"
    )
    XCTAssertEqual(
        MenuNumberFormat.resetCountdown.string(for: 183_600),
        "2 天 3 小时"
    )
}

func testAnimatableTextUsesInterpolatedValueInsteadOfFinalString() {
    var text = MenuInterpolatingNumberText(
        value: 100,
        format: .percentage
    )
    text.animatableData = 50
    XCTAssertEqual(text.renderedText, "50%")
}
```

- [ ] **步骤 2：运行测试并确认失败**

```bash
swift test --filter MenuRollingNumberTests
```

预期：因为数值格式和可插值文本尚未定义而编译失败。

- [ ] **步骤 3：实现格式类型与可插值文本**

`MenuNumberFormat` 包含：

```swift
case integer
case groupedInteger
case percentage
case tokens
case days
case duration
case resetCountdown
```

所有格式先将负数归零，再按现有 `MetricFormatter` 或明确的整数规则输出。`MenuInterpolatingNumberText` 的 `animatableData` 直接读写 `value`，`body` 和可测试的 `renderedText` 都调用同一个格式方法。

- [ ] **步骤 4：重构数字滚动容器**

`MenuRollingNumberText` 改为接收：

```swift
let value: Double?
let format: MenuNumberFormat
```

组件内部保存 `displayedValue`。展示周期变化时无动画设为零，等待 `60_000_000` 纳秒后用 1.2 秒动画设置为目标值。目标实时值变化时直接从当前动画状态过渡；缺失值显示 `—`；辅助功能标签始终使用最终值。删除字符串 `targetText`、`zeroText` 和 `.numericText()` 过渡。

- [ ] **步骤 5：运行测试并提交**

```bash
swift test --filter MenuRollingNumberTests
git add Sources/CodexMonitor/MenuBar/MenuRollingNumberText.swift \
  Tests/CodexMonitorTests/MenuRollingNumberTests.swift
git commit -m "修复：使用真实数值驱动菜单滚动"
```

---

### 任务二：让面板显示完成后启动动画

**文件：**

- 修改：`Sources/CodexMonitor/MenuBar/MenuBarController.swift`
- 修改：`Tests/CodexMonitorTests/MenuRollingNumberTests.swift`

**接口：**

- 消费：`MenuNumberAnimationContext.beginPresentation()`
- 产生：每次 `popoverDidShow(_:)` 触发一个新展示周期。

- [ ] **步骤 1：增加展示周期状态测试**

继续保留并运行：

```swift
@MainActor
func testEveryPresentationAdvancesAnimationCycle()
```

该测试保证每次调用都会产生新的周期；控制器把调用时机从 `showPopover()` 前移动到 `popoverDidShow(_:)`。

- [ ] **步骤 2：修改控制器**

删除 `showPopover()` 中的：

```swift
numberAnimationContext.beginPresentation()
```

在 `popoverDidShow(_:)` 的最前面调用该方法，之后再更新悬停协调器和无障碍状态。

- [ ] **步骤 3：运行相关测试并提交**

```bash
swift test --filter MenuRollingNumberTests
swift test --filter MenuHoverCoordinatorTests
swift test --filter AppIntegrationTests
git add Sources/CodexMonitor/MenuBar/MenuBarController.swift
git commit -m "修复：面板显示后启动数字滚动"
```

---

### 任务三：把所有动态指标改为原始实时数值

**文件：**

- 修改：`Sources/CodexMonitor/MenuBar/MenuWeeklyQuotaSection.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuDailyActivitySection.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuProjectAnalyticsSection.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuStatisticsSection.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuGitHubActivitySection.swift`
- 修改：`Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift`

**接口：**

- 消费：`MenuRollingNumberText(value:format:)`
- 产生：所有指定区块传递原始 `Double` 实时数据。

- [ ] **步骤 1：先把本周额度展示模型测试改为数值契约**

`MenuWeeklyQuotaPresentation` 改为：

```swift
let remainingValue: Double?
let usedValue: Double?
let usedFraction: Double?
let resetSeconds: Double?
let isFresh: Bool
```

测试验证剩余 `34`、已用 `66`、重置 `183_600` 秒和缺失值均为 `nil`。

- [ ] **步骤 2：运行测试并确认失败**

```bash
swift test --filter MenuDashboardCompositionTests
```

预期：旧展示模型仍返回字符串，数值属性不存在。

- [ ] **步骤 3：接入本周额度和每日活动**

- 剩余额度：原始百分比 + `.integer`。
- 已用比例：原始百分比 + `.percentage`。
- 重置倒计时：剩余秒数 + `.resetCountdown`。
- 今日 Token：原始 Token + `.tokens`。
- 会话数：原始会话数 + `.integer`。
- 平均每日 Token：原始平均值 + `.tokens`。
- 连续使用：原始天数 + `.days`。

- [ ] **步骤 4：接入项目分析、统计总览和 GitHub**

- 项目七天总量与排名：原始 Token + `.tokens`。
- 累计 Token、峰值 Token：原始 Token + `.tokens`。
- 最长任务时长：原始秒数 + `.duration`。
- 当前与最长连续天数：原始天数 + `.days`。
- GitHub 总贡献：原始贡献数 + `.groupedInteger`。

- [ ] **步骤 5：运行区块、格式和布局测试并提交**

```bash
swift test --filter MenuDashboardCompositionTests
swift test --filter MenuRollingNumberTests
swift test --filter MenuPopoverLayoutTests
git add Sources/CodexMonitor/MenuBar/MenuWeeklyQuotaSection.swift \
  Sources/CodexMonitor/MenuBar/MenuDailyActivitySection.swift \
  Sources/CodexMonitor/MenuBar/MenuProjectAnalyticsSection.swift \
  Sources/CodexMonitor/MenuBar/MenuStatisticsSection.swift \
  Sources/CodexMonitor/MenuBar/MenuGitHubActivitySection.swift \
  Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift
git commit -m "修复：接入全部菜单实时指标"
```

---

### 任务四：更新版本并重新打包

**文件：**

- 修改：`Resources/Info.plist`
- 修改：`Tests/CodexMonitorTests/AppIntegrationTests.swift`
- 生成：`dist/Codex Monitor.app`

- [ ] **步骤 1：将版本测试更新为 `0.1.19 (20)` 并确认失败**

```bash
swift test --filter AppIntegrationTests/testAppMetadataDeclaresPackagedIcon
```

- [ ] **步骤 2：更新 `Resources/Info.plist`**

设置：

```text
CFBundleShortVersionString = 0.1.19
CFBundleVersion = 20
```

- [ ] **步骤 3：完整验证并提交**

```bash
swift test
git diff --check
git add Resources/Info.plist Tests/CodexMonitorTests/AppIntegrationTests.swift
git commit -m "构建：更新实时数字滚动修复版本"
```

- [ ] **步骤 4：请求独立代码审查**

审查范围为本计划开始前提交至最新提交，重点检查真实插值、展示周期时机、任务取消、格式准确性和布局风险。修复所有 Critical 和 Important。

- [ ] **步骤 5：重新运行完整测试并打包**

```bash
swift test
bash scripts/package-app.sh
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
  "dist/Codex Monitor.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" \
  "dist/Codex Monitor.app/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "dist/Codex Monitor.app"
```

预期：完整测试零失败，生成版本为 `0.1.19 (20)` 且签名有效的测试包。
