# macOS 菜单栏紧凑单页面板实施计划

> **面向代理式开发者：** 必须使用 `superpowers:executing-plans` 按任务执行本计划。每个步骤使用复选框跟踪。

**目标：** 将菜单栏单页面板改为 `640 × 630 pt` 的无滚动三行网格，同时恢复并原样保留刘海五页入口。

**架构：** `MenuPopoverLayout` 同时负责面板尺寸与三行高度分配，`MenuDashboardView` 使用固定 `VStack`、`HStack` 组合五个独立模块。活动热力图和仓库网格增加仅供菜单面板使用的紧凑密度，默认密度不变，因此刘海页面视觉不变；`AppDelegate` 重新管理 `NotchWindowController` 生命周期。

**技术栈：** Swift 6.2、SwiftUI、AppKit、XCTest、Swift Package Manager。

## 全局约束

- 直接在用户已授权的 `main` 分支开发。
- 所有文档和 Git 提交信息使用中文。
- 目标内容尺寸固定为 `640 × 630 pt`。
- 菜单单页面板不使用横向或纵向 `ScrollView`。
- 原 `NotchDashboardView` 及五个页面不修改布局、文字、动画和数据逻辑。
- 点击菜单栏状态区域仍只打开紧凑单页面板。
- 不修改 Windows 版本、统计口径、GitHub 授权和钥匙串条目。

---

### 任务一：定义紧凑尺寸和三行网格

**文件：**

- 修改：`Sources/CodexMonitor/MenuBar/MenuPopoverLayout.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuDashboardView.swift`
- 修改：`Tests/CodexMonitorTests/MenuPopoverLayoutTests.swift`
- 修改：`Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift`

**接口：**

- 产出：`MenuPopoverLayout.targetSize == CGSize(width: 640, height: 630)`
- 产出：`MenuDashboardLayoutPlan.make(contentHeight:) -> MenuDashboardLayoutPlan`
- 产出：`MenuDashboardComposition.rows: [[MenuDashboardSection]]`
- 消费：现有五个 `MenuDashboardSection`

- [ ] **步骤 1：为新尺寸和高度分配编写失败测试**

```swift
func testUsesCompactTargetSizeWhenScreenHasEnoughSpace() {
    let size = MenuPopoverLayout.contentSize(
        for: CGRect(x: 0, y: 0, width: 1440, height: 1000)
    )
    XCTAssertEqual(size, CGSize(width: 640, height: 630))
}

func testCompactRowsFitInsideAvailableContentHeight() {
    let plan = MenuDashboardLayoutPlan.make(contentHeight: 558)
    XCTAssertEqual(
        plan.firstRowHeight + plan.projectRowHeight
            + plan.thirdRowHeight + plan.rowSpacing * 2,
        558,
        accuracy: 0.001
    )
}
```

- [ ] **步骤 2：运行布局测试并确认失败**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/private/tmp/codex-monitor-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-monitor-module-cache \
  xcrun swift test --disable-sandbox --filter MenuPopoverLayoutTests
```

预期：目标尺寸仍为 `720 × 840`，且 `MenuDashboardLayoutPlan` 尚不存在。

- [ ] **步骤 3：实现尺寸和可验证的高度分配**

```swift
enum MenuPopoverLayout {
    static let targetSize = CGSize(width: 640, height: 630)
    static let screenInset: CGFloat = 24
}

struct MenuDashboardLayoutPlan: Equatable {
    let firstRowHeight: CGFloat
    let projectRowHeight: CGFloat
    let thirdRowHeight: CGFloat
    let rowSpacing: CGFloat

    static func make(contentHeight: CGFloat) -> Self {
        let spacing: CGFloat = 8
        let usable = max(0, contentHeight - spacing * 2)
        let first = min(138, usable)
        let project = min(180, max(0, usable - first))
        return Self(
            firstRowHeight: first,
            projectRowHeight: project,
            thirdRowHeight: max(0, usable - first - project),
            rowSpacing: spacing
        )
    }
}
```

- [ ] **步骤 4：为三行模块分组编写失败测试**

```swift
func testCompactDashboardUsesThreeRows() {
    XCTAssertEqual(
        MenuDashboardComposition.rows,
        [
            [.weeklyQuota, .dailyActivity],
            [.projectAnalytics],
            [.statistics, .github]
        ]
    )
}
```

- [ ] **步骤 5：运行组合测试并确认 `rows` 缺失**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/private/tmp/codex-monitor-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-monitor-module-cache \
  xcrun swift test --disable-sandbox --filter MenuDashboardCompositionTests
```

预期：编译失败，提示 `MenuDashboardComposition` 没有 `rows`。

- [ ] **步骤 6：把根视图改为无滚动三行网格**

```swift
enum MenuDashboardComposition {
    static let rows: [[MenuDashboardSection]] = [
        [.weeklyQuota, .dailyActivity],
        [.projectAnalytics],
        [.statistics, .github]
    ]
}
```

`MenuDashboardView` 使用 `GeometryReader` 取得内容高度，再使用固定三行：

```swift
VStack(spacing: plan.rowSpacing) {
    HStack(spacing: 8) {
        weeklyQuotaSection
        dailyActivitySection
    }
    .frame(height: plan.firstRowHeight)

    projectAnalyticsSection
        .frame(height: plan.projectRowHeight)

    HStack(spacing: 8) {
        statisticsSection.frame(width: contentWidth * 0.36)
        githubSection
    }
    .frame(height: plan.thirdRowHeight)
}
```

顶部固定 `44 pt`，底部固定 `28 pt`，内容区外边距 `12 pt`。删除原来的纵向 `ScrollView` 和 `LazyVStack`。

- [ ] **步骤 7：运行两组测试并确认通过**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/private/tmp/codex-monitor-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-monitor-module-cache \
  xcrun swift test --disable-sandbox \
  --filter 'MenuPopoverLayoutTests|MenuDashboardCompositionTests'
```

预期：新尺寸、高度分配和三行组合测试全部通过。

- [ ] **步骤 8：提交**

```bash
git add Sources/CodexMonitor/MenuBar/MenuPopoverLayout.swift \
  Sources/CodexMonitor/MenuBar/MenuDashboardView.swift \
  Tests/CodexMonitorTests/MenuPopoverLayoutTests.swift \
  Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift
git commit -m "布局：建立菜单栏紧凑三行网格"
```

---

### 任务二：压缩五个模块并保留交互

**文件：**

- 修改：`Sources/CodexMonitor/MenuBar/MenuDashboardComponents.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuWeeklyQuotaSection.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuDailyActivitySection.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuProjectAnalyticsSection.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuStatisticsSection.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuGitHubActivitySection.swift`
- 修改：`Sources/CodexMonitor/Notch/ActivityHeatmap.swift`
- 修改：`Sources/CodexMonitor/GitHub/RecentRepositoryGrid.swift`
- 修改：`Tests/CodexMonitorTests/VisualFeedbackTests.swift`
- 修改：`Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift`

**接口：**

- 产出：`ActivityHeatmapDensity.standard` 与 `.compact`
- 产出：`ActivityHeatmapMetrics.make(density:)`
- 产出：`RepositoryGridDensity.standard` 与 `.compact`
- 产出：`RepositoryGridMetrics.make(density:)`
- 保留：`ActivityHeatmap(days:)` 和 `RecentRepositoryGrid(repositories:)` 默认视觉行为

- [ ] **步骤 1：为紧凑热力图和仓库行编写失败测试**

```swift
func testCompactActivityHeatmapIsShorterThanStandardLayout() {
    let standard = ActivityHeatmapMetrics.make(density: .standard)
    let compact = ActivityHeatmapMetrics.make(density: .compact)
    XCTAssertLessThan(compact.totalHeight, standard.totalHeight)
    XCTAssertEqual(compact.rowCount, 7)
}

func testCompactRepositoryGridFitsThreeRowsInsideEightyPoints() {
    let metrics = RepositoryGridMetrics.make(density: .compact)
    XCTAssertEqual(metrics.rowCount, 3)
    XCTAssertLessThanOrEqual(metrics.totalHeight, 80)
}
```

- [ ] **步骤 2：运行相关测试并确认类型缺失**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/private/tmp/codex-monitor-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-monitor-module-cache \
  xcrun swift test --disable-sandbox \
  --filter 'VisualFeedbackTests|MenuDashboardCompositionTests'
```

预期：编译失败，提示紧凑密度和指标类型尚未定义。

- [ ] **步骤 3：实现带默认值的紧凑密度**

```swift
enum ActivityHeatmapDensity {
    case standard
    case compact
}

struct ActivityHeatmapMetrics {
    let rowCount: Int
    let cellSize: CGFloat
    let cellSpacing: CGFloat
    let legendHeight: CGFloat
    var totalHeight: CGFloat {
        CGFloat(rowCount) * cellSize
            + CGFloat(rowCount - 1) * cellSpacing
            + 5 + legendHeight
    }
}
```

`ActivityHeatmap` 新增默认参数 `density: ActivityHeatmapDensity = .standard`。标准参数保持现有 `11 pt` 格子和 `3 pt` 间距；紧凑参数使用约 `7 pt` 格子和 `2 pt` 间距。菜单每日活动传入 `.compact`，刘海页面不传参数。

`RecentRepositoryGrid` 新增默认参数 `density: RepositoryGridDensity = .standard`。标准行高保持 `30 pt`，紧凑行高使用 `24 pt`，菜单 GitHub 模块传入 `.compact`。

- [ ] **步骤 4：重新排列五个模块**

具体修改：

- 公共卡片内边距改为 `10 pt`、圆角改为 `13 pt`。
- 本周额度缩短标题和主体间距，剩余额度列宽约 `82 pt`。
- 每日活动使用紧凑热力图，右侧指标改为两列两行。
- 项目分析图表高度约 `82 pt`，排名宽度约 `200 pt`，保留悬停说明。
- 统计总览改为两行网格：第一行两项，第二行三项。
- GitHub 标题行同时展示贡献总数，热力图约 `42 pt`，最近仓库使用两列三行紧凑网格。
- 未授权 GitHub 卡片压缩到第三行可用高度。

- [ ] **步骤 5：运行相关测试并确认通过**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/private/tmp/codex-monitor-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-monitor-module-cache \
  xcrun swift test --disable-sandbox \
  --filter 'VisualFeedbackTests|MenuDashboardCompositionTests|GitHubModelsTests'
```

预期：热力图仍为七行、仓库仍限制六个，紧凑布局指标测试全部通过。

- [ ] **步骤 6：提交**

```bash
git add Sources/CodexMonitor/MenuBar \
  Sources/CodexMonitor/Notch/ActivityHeatmap.swift \
  Sources/CodexMonitor/GitHub/RecentRepositoryGrid.swift \
  Tests/CodexMonitorTests/VisualFeedbackTests.swift \
  Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift
git commit -m "布局：压缩菜单面板数据模块"
```

---

### 任务三：恢复刘海入口并生成最终安装包

**文件：**

- 修改：`Sources/CodexMonitor/App/AppDelegate.swift`
- 修改：`Sources/CodexMonitor/App/AppMetadata.swift`
- 修改：`Tests/CodexMonitorTests/AppIntegrationTests.swift`

**接口：**

- 产出：`AppSurfaceLifecycle.start()` 和 `stop()`
- 消费：现有 `MenuBarController`、`NotchWindowController`
- 保留：`NotchDashboardView` 及其五页代码不变

- [ ] **步骤 1：为界面控制器生命周期编写失败测试**

使用测试替身记录真实生命周期协调器的可观察调用：

```swift
@MainActor
func testAppSurfaceLifecycleStartsAndStopsEverySurface() {
    let menu = RecordingAppSurface()
    let notch = RecordingAppSurface()
    let lifecycle = AppSurfaceLifecycle(surfaces: [menu, notch])

    lifecycle.start()
    lifecycle.stop()

    XCTAssertEqual(menu.events, [.started, .stopped])
    XCTAssertEqual(notch.events, [.started, .stopped])
}
```

- [ ] **步骤 2：运行测试并确认生命周期类型缺失**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/private/tmp/codex-monitor-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-monitor-module-cache \
  xcrun swift test --disable-sandbox --filter AppIntegrationTests
```

预期：编译失败，提示 `AppSurfaceLifecycle` 尚未定义。

- [ ] **步骤 3：实现生命周期并接回刘海控制器**

```swift
@MainActor
protocol AppSurfaceControlling: AnyObject {
    func start()
    func stop()
}

@MainActor
final class AppSurfaceLifecycle {
    private let surfaces: [AppSurfaceControlling]

    init(surfaces: [AppSurfaceControlling]) {
        self.surfaces = surfaces
    }

    func start() {
        surfaces.forEach { $0.start() }
    }

    func stop() {
        surfaces.forEach { $0.stop() }
    }
}
```

让 `MenuBarController` 和 `NotchWindowController` 遵循协议；`MenuBarController.stop()` 负责关闭面板和移除状态项。`AppDelegate` 创建两个控制器并交给同一个生命周期对象，在启动时调用 `start()`，退出时调用 `stop()`。

- [ ] **步骤 4：提升应用版本**

将版本从 `0.1.13 (14)` 提升为 `0.1.14 (15)`。

- [ ] **步骤 5：运行完整测试**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/private/tmp/codex-monitor-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-monitor-module-cache \
  xcrun swift test --disable-sandbox
```

预期：全部测试通过，0 失败。

- [ ] **步骤 6：提交**

```bash
git add Sources/CodexMonitor/App/AppDelegate.swift \
  Sources/CodexMonitor/App/AppMetadata.swift \
  Sources/CodexMonitor/MenuBar/MenuBarController.swift \
  Sources/CodexMonitor/Notch/NotchWindowController.swift \
  Tests/CodexMonitorTests/AppIntegrationTests.swift
git commit -m "功能：恢复刘海分页入口并更新版本"
```

- [ ] **步骤 7：重新打包并校验签名**

```bash
bash scripts/package-app.sh
codesign --verify --deep --strict --verbose=2 "dist/Codex Monitor.app"
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
  "dist/Codex Monitor.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" \
  "dist/Codex Monitor.app/Contents/Info.plist"
```

预期：应用签名有效，版本为 `0.1.14`，构建号为 `15`。
