# 菜单额度进度条动画实施计划

> **面向执行代理：** 必须使用 `superpowers:executing-plans` 或 `superpowers:subagent-driven-development` 按任务执行；所有实现步骤使用测试驱动开发。

**目标：** 让菜单栏下拉面板中的本周额度进度条随面板展示、实时刷新和关闭状态平滑变化。

**架构：** 新增一个只负责比例动画的 SwiftUI 视图，复用现有 `MenuNumberAnimationContext` 控制面板展示周期。动画决策由可测试的纯函数产生，额度页面只负责提供 `usedFraction` 和轨道宽度，不改变现有布局。

**技术栈：** Swift 6、SwiftUI、Combine、XCTest、Swift Package Manager、macOS 14。

## 全局约束

- 打开面板时先保持 0 共 60 毫秒，再用 `easeOut` 在 1.2 秒内增长到实时比例。
- 面板展示期间刷新时从当前长度动画到新比例；隐藏期间更新保持 0。
- 面板关闭或应用停止时取消延迟任务并立即归零。
- 系统启用“减少动态效果”时直接显示最终比例。
- 输入比例统一限制在 `0...1`，缺少数据时不绘制紫色进度。
- 不修改轨道颜色、高度、卡片布局和其他页面。
- 应用版本更新为 `0.1.20 (21)`。

---

### 任务一：定义可测试的进度动画决策

**文件：**

- 修改：`Tests/CodexMonitorTests/MenuRollingNumberTests.swift`
- 新建：`Sources/CodexMonitor/MenuBar/MenuAnimatedQuotaProgress.swift`

**接口：**

- 复用：`MenuAnimationTiming.zeroHoldNanoseconds`、`MenuAnimationTiming.numberDuration`
- 复用：`MenuNumberAnimationPlan.UpdateAction`
- 产出：`MenuQuotaProgressAnimationPlan.initialProgress(targetProgress:reduceMotion:) -> Double`
- 产出：`MenuQuotaProgressAnimationPlan.normalized(_:) -> Double`
- 产出：`MenuQuotaProgressAnimationPlan.updateAction(isPresented:reduceMotion:) -> MenuNumberAnimationPlan.UpdateAction`

- [ ] **步骤 1：先编写失败测试**

```swift
func testQuotaProgressStartsAtZeroAndClampsTargets() {
    XCTAssertEqual(
        MenuQuotaProgressAnimationPlan.initialProgress(
            targetProgress: 0.66,
            reduceMotion: false
        ),
        0
    )
    XCTAssertEqual(MenuQuotaProgressAnimationPlan.normalized(-0.3), 0)
    XCTAssertEqual(MenuQuotaProgressAnimationPlan.normalized(1.4), 1)
}

func testReducedMotionQuotaProgressStartsAtTarget() {
    XCTAssertEqual(
        MenuQuotaProgressAnimationPlan.initialProgress(
            targetProgress: 0.66,
            reduceMotion: true
        ),
        0.66
    )
}

func testHiddenQuotaProgressUpdateHoldsAtZero() {
    XCTAssertEqual(
        MenuQuotaProgressAnimationPlan.updateAction(
            isPresented: false,
            reduceMotion: false
        ),
        .holdZero
    )
}
```

- [ ] **步骤 2：运行测试并确认红灯**

运行：

```bash
swift test --filter MenuRollingNumberTests
```

预期：因 `MenuQuotaProgressAnimationPlan` 尚不存在而编译失败。

- [ ] **步骤 3：实现最小动画决策**

```swift
enum MenuQuotaProgressAnimationPlan {
    static func normalized(_ progress: Double) -> Double {
        max(0, min(1, progress))
    }

    static func initialProgress(
        targetProgress: Double,
        reduceMotion: Bool
    ) -> Double {
        reduceMotion ? normalized(targetProgress) : 0
    }

    static func updateAction(
        isPresented: Bool,
        reduceMotion: Bool
    ) -> MenuNumberAnimationPlan.UpdateAction {
        MenuNumberAnimationPlan.updateAction(
            isPresented: isPresented,
            reduceMotion: reduceMotion
        )
    }
}
```

- [ ] **步骤 4：运行测试并确认绿灯**

运行：

```bash
swift test --filter MenuRollingNumberTests
```

预期：所有 `MenuRollingNumberTests` 通过。

- [ ] **步骤 5：中文提交**

```bash
git add Sources/CodexMonitor/MenuBar/MenuAnimatedQuotaProgress.swift Tests/CodexMonitorTests/MenuRollingNumberTests.swift
git commit -m "功能：增加额度进度动画决策"
```

### 任务二：实现并接入额度进度条视图

**文件：**

- 修改：`Sources/CodexMonitor/MenuBar/MenuAnimatedQuotaProgress.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuWeeklyQuotaSection.swift`

**接口：**

- 输入：`MenuAnimatedQuotaProgress(targetProgress: Double?, availableWidth: CGFloat)`
- 环境：`MenuNumberAnimationContext`
- 输出：宽度为 `availableWidth * displayedProgress` 的紫色胶囊

- [ ] **步骤 1：为插值比例编写失败测试**

```swift
@MainActor
func testInterpolatingQuotaProgressUsesIntermediateWidth() {
    var progress = MenuInterpolatingQuotaProgress(
        progress: 1,
        availableWidth: 200
    )
    progress.animatableData = 0.5
    XCTAssertEqual(progress.renderedWidth, 100)
}
```

- [ ] **步骤 2：运行测试并确认红灯**

运行：

```bash
swift test --filter MenuRollingNumberTests/testInterpolatingQuotaProgressUsesIntermediateWidth
```

预期：因 `MenuInterpolatingQuotaProgress` 尚不存在而编译失败。

- [ ] **步骤 3：实现真实比例插值和生命周期**

`MenuInterpolatingQuotaProgress` 使用 `Animatable` 的 `Double` 作为 `animatableData`，公开只读 `renderedWidth` 供测试验证。

`MenuAnimatedQuotaProgress`：

- `onAppear`：仅在面板已展示时从零重播，否则保持零。
- `cycle` 变化：面板展示时从零重播。
- `isPresented` 变为 `false`：取消任务并归零。
- `targetProgress` 变化：按 `updateAction` 选择保持零、直接设置或动画到目标。
- `accessibilityReduceMotion` 变化：展示时重播对应模式，隐藏时保持零。
- `onDisappear`：取消任务。

- [ ] **步骤 4：替换额度页面中的固定宽度**

将：

```swift
Capsule()
    .fill(MenuDashboardVisual.accent)
    .frame(width: proxy.size.width * usedFraction)
```

替换为：

```swift
MenuAnimatedQuotaProgress(
    targetProgress: quota.usedFraction,
    availableWidth: proxy.size.width
)
```

- [ ] **步骤 5：运行菜单动画与额度展示测试**

运行：

```bash
swift test --filter MenuRollingNumberTests
swift test --filter MenuDashboardCompositionTests
```

预期：两组测试全部通过。

- [ ] **步骤 6：中文提交**

```bash
git add Sources/CodexMonitor/MenuBar/MenuAnimatedQuotaProgress.swift Sources/CodexMonitor/MenuBar/MenuWeeklyQuotaSection.swift Tests/CodexMonitorTests/MenuRollingNumberTests.swift
git commit -m "功能：额度进度条随面板平滑变化"
```

### 任务三：升级版本并生成应用包

**文件：**

- 修改：`Tests/CodexMonitorTests/AppIntegrationTests.swift`
- 修改：`Resources/Info.plist`
- 生成：`dist/Codex Monitor.app`

**接口：**

- 包版本：`CFBundleShortVersionString = 0.1.20`
- 构建号：`CFBundleVersion = 21`

- [ ] **步骤 1：先将版本断言更新为 `0.1.20 (21)`**

```swift
XCTAssertEqual(
    plist["CFBundleShortVersionString"] as? String,
    "0.1.20"
)
XCTAssertEqual(plist["CFBundleVersion"] as? String, "21")
```

- [ ] **步骤 2：运行版本测试并确认红灯**

运行：

```bash
swift test --filter AppIntegrationTests/testAppMetadataDeclaresPackagedIcon
```

预期：实际值仍为 `0.1.19 (20)`，测试失败。

- [ ] **步骤 3：更新 `Resources/Info.plist`**

```xml
<key>CFBundleShortVersionString</key>
<string>0.1.20</string>
<key>CFBundleVersion</key>
<string>21</string>
```

- [ ] **步骤 4：运行完整测试**

运行：

```bash
swift test
```

预期：全部测试通过且无失败。

- [ ] **步骤 5：中文提交**

```bash
git add Resources/Info.plist Tests/CodexMonitorTests/AppIntegrationTests.swift
git commit -m "构建：更新额度进度动画版本"
```

- [ ] **步骤 6：生产打包和签名验证**

运行：

```bash
bash scripts/package-app.sh
codesign --verify --deep --strict --verbose=2 "dist/Codex Monitor.app"
plutil -extract CFBundleShortVersionString raw "dist/Codex Monitor.app/Contents/Info.plist"
plutil -extract CFBundleVersion raw "dist/Codex Monitor.app/Contents/Info.plist"
git diff --check
git status --short
```

预期：签名有效，包版本为 `0.1.20`、构建号为 `21`，工作区干净。
