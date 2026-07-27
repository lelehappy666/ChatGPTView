# 菜单数字动画节奏优化实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 将菜单动态数字动画调整为 1.2 秒、项目柱状图动画调整为 1.0 秒，让变化过程清晰可见。

**架构：** 新增集中式动画节奏定义，数字文本和柱状图组件分别读取统一时长。保留现有展示周期、取消任务、减少动态效果和静态文字实现。

**技术栈：** Swift 6.2、SwiftUI、XCTest、Swift Package Manager。

## 全局约束

- 直接在 `main` 分支开发。
- 动态数字时长为 1.2 秒。
- 项目柱状图时长为 1.0 秒。
- 不修改静态说明、筛选、日期、月份、仓库更新时间和悬停提示。
- 不修改布局、配色、字号、面板尺寸与悬停开关逻辑。
- 版本更新为 `0.1.18 (19)`。

---

### 任务一：集中定义并接入动画节奏

**文件：**

- 修改：`Sources/CodexMonitor/MenuBar/MenuRollingNumberText.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuProjectAnalyticsSection.swift`
- 修改：`Tests/CodexMonitorTests/MenuRollingNumberTests.swift`

**接口：**

- 产生：`MenuAnimationTiming.numberDuration == 1.2`
- 产生：`MenuAnimationTiming.chartDuration == 1.0`
- 消费：`MenuRollingNumberText` 与 `MenuAnimatedTokenBar`

- [ ] **步骤 1：编写失败测试**

```swift
func testAnimationTimingKeepsNumbersReadable() {
    XCTAssertEqual(MenuAnimationTiming.numberDuration, 1.2)
    XCTAssertEqual(MenuAnimationTiming.chartDuration, 1.0)
}
```

- [ ] **步骤 2：运行测试并确认失败**

```bash
swift test --filter MenuRollingNumberTests/testAnimationTimingKeepsNumbersReadable
```

预期：因 `MenuAnimationTiming` 尚未定义而编译失败。

- [ ] **步骤 3：实现统一节奏并替换原时长**

```swift
enum MenuAnimationTiming {
    static let numberDuration = 1.2
    static let chartDuration = 1.0
}
```

数字文本两个动画入口都使用 `numberDuration`；柱状图打开重播和刷新变化两个入口都使用 `chartDuration`。动画曲线继续使用 `.easeOut`。

- [ ] **步骤 4：运行测试并提交**

```bash
swift test --filter MenuRollingNumberTests
git add Sources/CodexMonitor/MenuBar/MenuRollingNumberText.swift \
  Sources/CodexMonitor/MenuBar/MenuProjectAnalyticsSection.swift \
  Tests/CodexMonitorTests/MenuRollingNumberTests.swift
git commit -m "优化：放慢菜单数字动画"
```

---

### 任务二：更新版本并重新打包

**文件：**

- 修改：`Resources/Info.plist`
- 修改：`Tests/CodexMonitorTests/AppIntegrationTests.swift`
- 生成：`dist/Codex Monitor.app`

- [ ] **步骤 1：把版本测试更新为 `0.1.18 (19)` 并确认失败**

```swift
XCTAssertEqual(plist["CFBundleShortVersionString"] as? String, "0.1.18")
XCTAssertEqual(plist["CFBundleVersion"] as? String, "19")
```

```bash
swift test --filter AppIntegrationTests/testAppMetadataDeclaresPackagedIcon
```

预期：当前 `0.1.17 (18)` 与期望不一致。

- [ ] **步骤 2：更新应用版本**

将 `Resources/Info.plist` 更新为 `0.1.18 (19)`。

- [ ] **步骤 3：运行完整验证并提交**

```bash
swift test
git diff --check
git add Resources/Info.plist Tests/CodexMonitorTests/AppIntegrationTests.swift
git commit -m "构建：更新菜单动画节奏版本"
```

- [ ] **步骤 4：打包和核验**

```bash
bash scripts/package-app.sh
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
  "dist/Codex Monitor.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" \
  "dist/Codex Monitor.app/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "dist/Codex Monitor.app"
```

预期：生成版本为 `0.1.18 (19)` 且深度签名有效的测试包。
