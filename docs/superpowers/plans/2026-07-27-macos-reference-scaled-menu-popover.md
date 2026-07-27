# macOS 参考图等比缩放菜单面板实施计划

> **面向代理式开发者：** 必须使用 `superpowers:executing-plans` 按任务执行本计划。步骤使用复选框跟踪。

**目标：** 严格按照用户提供的参考图，把完整单列 UI 等比例缩小为约 `420 × 720 pt` 的菜单栏下拉面板，同时修复刘海周额度旧记录被隐藏和手动刷新后仍为空的问题。

**架构：** 使用共享 `QuotaDisplayState` 区分无记录、新鲜记录和最后一次记录，让刘海页、菜单栏文字和新面板使用相同额度状态。`MenuDashboardView` 在固定参考画布中按参考图顺序组合五张全宽卡片，再根据可用屏幕使用单一缩放系数整体缩小；各卡片继续消费现有 `MonitorStore`、项目分析和 GitHub 数据。

**技术栈：** Swift 6.2、SwiftUI、AppKit、Canvas、XCTest、Swift Package Manager。

## 全局约束

- 直接在用户已授权的 `main` 分支开发。
- 所有文档和 Git 提交信息使用中文。
- 参考图是唯一视觉和排版基准。
- 目标逻辑尺寸约为 `420 × 720 pt`。
- 所有 UI 使用同一个缩放比例。
- 不使用横向或纵向 `ScrollView`。
- 模块顺序固定为本周额度、每日活动、项目分析、统计总览、GitHub 活跃。
- 原刘海五页布局、左右滑动和悬停开关保持不变。
- 不修改 Windows 版本、统计口径、GitHub 授权方式和钥匙串条目。

---

### 任务一：保留最后一次周额度并正确标记状态

**文件：**

- 修改：`Sources/CodexMonitor/Domain/MonitorModels.swift`
- 修改：`Sources/CodexMonitor/Notch/WeeklyQuotaPage.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuBarContentView.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuWeeklyQuotaSection.swift`
- 修改：`Tests/CodexMonitorTests/MonitorModelsTests.swift`
- 修改：`Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift`

**接口：**

- 产出：`QuotaDisplayState`
- 产出：`QuotaFreshnessPolicy.displayState(for:at:) -> QuotaDisplayState`
- 消费：`WeeklyQuota.remainingPercent` 与 `WeeklyQuota.updatedAt`
- 保留：`QuotaFreshnessPolicy.visibleRemainingPercent(for:at:)` 只返回新鲜值

- [ ] **步骤 1：编写旧额度仍可展示的失败测试**

```swift
func testQuotaDisplayStateKeepsLastKnownValueAfterFreshWindow() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let quota = WeeklyQuota(
        remainingPercent: 77,
        resetsAt: now.addingTimeInterval(6 * 86_400),
        updatedAt: now.addingTimeInterval(-2_600)
    )

    XCTAssertEqual(
        QuotaFreshnessPolicy.displayState(for: quota, at: now),
        .lastKnown(remainingPercent: 77)
    )
}

func testQuotaDisplayStateDistinguishesMissingAndFreshValues() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    XCTAssertEqual(
        QuotaFreshnessPolicy.displayState(
            for: WeeklyQuota(remainingPercent: nil, resetsAt: nil),
            at: now
        ),
        .unavailable
    )
    XCTAssertEqual(
        QuotaFreshnessPolicy.displayState(
            for: WeeklyQuota(
                remainingPercent: 76,
                resetsAt: nil,
                updatedAt: now.addingTimeInterval(-60)
            ),
            at: now
        ),
        .fresh(remainingPercent: 76)
    )
}
```

- [ ] **步骤 2：运行额度模型测试并确认类型缺失**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/private/tmp/codex-monitor-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-monitor-module-cache \
  xcrun swift test --disable-sandbox --filter MonitorModelsTests
```

预期：编译失败，提示 `QuotaDisplayState` 或 `displayState` 尚不存在。

- [ ] **步骤 3：实现共享额度展示状态**

```swift
enum QuotaDisplayState: Equatable {
    case unavailable
    case fresh(remainingPercent: Double)
    case lastKnown(remainingPercent: Double)

    var remainingPercent: Double? {
        switch self {
        case .unavailable: nil
        case .fresh(let value), .lastKnown(let value): value
        }
    }

    var isFresh: Bool {
        if case .fresh = self { return true }
        return false
    }
}
```

`displayState` 在缺少数值或时间戳时返回 `.unavailable`；在 `visibleRemainingPercent` 返回值时返回 `.fresh`；其他存在数值的情况返回 `.lastKnown`。

- [ ] **步骤 4：修改三个额度入口**

- `WeeklyQuotaPage` 使用 `displayState.remainingPercent` 绘制剩余额度、已用进度和重置时间，并把 `displayState.isFresh` 传给 `QuotaRefreshPresentation`。
- `MenuBarContentView` 在 `.fresh` 和 `.lastKnown` 时都显示 `Week xx%`，只有 `.unavailable` 显示 `Week —`。
- `MenuWeeklyQuotaPresentation` 在 `.lastKnown` 时保留数值、已用比例和重置时间；刷新状态仍显示 `等待 Codex 更新`。

- [ ] **步骤 5：更新菜单额度测试**

```swift
func testWeeklyQuotaPresentationKeepsLastKnownQuotaWithoutClaimingFreshness() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let presentation = MenuWeeklyQuotaPresentation.make(
        quota: WeeklyQuota(
            remainingPercent: 77,
            resetsAt: now.addingTimeInterval(86_400),
            updatedAt: now.addingTimeInterval(-2_600)
        ),
        now: now
    )

    XCTAssertEqual(presentation.remainingText, "77")
    XCTAssertEqual(presentation.usedText, "23%")
    XCTAssertEqual(presentation.usedFraction, 0.23)
    XCTAssertFalse(presentation.isFresh)
}
```

- [ ] **步骤 6：运行额度相关测试**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/private/tmp/codex-monitor-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-monitor-module-cache \
  xcrun swift test --disable-sandbox \
  --filter 'MonitorModelsTests|MenuDashboardCompositionTests|QuotaRefreshPresentationTests'
```

预期：旧额度保留、无额度仍为空、新额度仍标记已同步。

- [ ] **步骤 7：提交**

```bash
git add Sources/CodexMonitor/Domain/MonitorModels.swift \
  Sources/CodexMonitor/Notch/WeeklyQuotaPage.swift \
  Sources/CodexMonitor/MenuBar/MenuBarContentView.swift \
  Sources/CodexMonitor/MenuBar/MenuWeeklyQuotaSection.swift \
  Tests/CodexMonitorTests/MonitorModelsTests.swift \
  Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift
git commit -m "修复：保留最后一次周额度记录"
```

---

### 任务二：建立参考图画布和等比例屏幕适配

**文件：**

- 修改：`Sources/CodexMonitor/MenuBar/MenuPopoverLayout.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuDashboardView.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuDashboardComponents.swift`
- 修改：`Tests/CodexMonitorTests/MenuPopoverLayoutTests.swift`
- 修改：`Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift`
- 修改：`Tests/CodexMonitorTests/LayoutContractTests.swift`

**接口：**

- 产出：`MenuPopoverLayout.targetSize == CGSize(width: 420, height: 720)`
- 产出：`MenuPopoverLayout.scaleFactor(for:) -> CGFloat`
- 产出：`MenuReferenceLayoutPlan`
- 产出：`MenuDashboardComposition.sections`

- [ ] **步骤 1：编写等比例尺寸失败测试**

```swift
func testUsesReferenceTargetSizeWhenScreenHasEnoughSpace() {
    XCTAssertEqual(
        MenuPopoverLayout.contentSize(
            for: CGRect(x: 0, y: 0, width: 1440, height: 1000)
        ),
        CGSize(width: 420, height: 720)
    )
}

func testSmallScreenPreservesReferenceAspectRatio() {
    let size = MenuPopoverLayout.contentSize(
        for: CGRect(x: 0, y: 0, width: 500, height: 600)
    )
    XCTAssertEqual(size.width / size.height, 420.0 / 720.0, accuracy: 0.001)
    XCTAssertLessThanOrEqual(size.width, 476)
    XCTAssertLessThanOrEqual(size.height, 576)
}
```

- [ ] **步骤 2：运行布局测试并确认旧尺寸失败**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/private/tmp/codex-monitor-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-monitor-module-cache \
  xcrun swift test --disable-sandbox \
  --filter 'MenuPopoverLayoutTests|LayoutContractTests'
```

预期：当前 `640 × 630` 尺寸和独立宽高裁剪不符合断言。

- [ ] **步骤 3：实现单一缩放系数**

```swift
enum MenuPopoverLayout {
    static let targetSize = CGSize(width: 420, height: 720)
    static let screenInset: CGFloat = 24

    static func scaleFactor(for availableSize: CGSize) -> CGFloat {
        guard targetSize.width > 0, targetSize.height > 0 else { return 0 }
        return max(
            0,
            min(
                1,
                availableSize.width / targetSize.width,
                availableSize.height / targetSize.height
            )
        )
    }
}
```

`contentSize` 使用 `visibleFrame - screenInset` 得到可用尺寸，再返回 `targetSize * scaleFactor`。

- [ ] **步骤 4：定义固定参考图高度**

```swift
struct MenuReferenceLayoutPlan: Equatable {
    let headerHeight: CGFloat = 42
    let quotaHeight: CGFloat = 80
    let dailyHeight: CGFloat = 120
    let projectHeight: CGFloat = 130
    let statisticsHeight: CGFloat = 80
    let githubHeight: CGFloat = 182
    let footerHeight: CGFloat = 30
    let spacing: CGFloat = 6
    let padding: CGFloat = 10
}
```

这些高度、六个间距和上下边距的总和必须等于 `720 pt`。

- [ ] **步骤 5：把根视图改为固定单列画布**

`MenuDashboardView` 使用 `GeometryReader` 计算整体缩放比例，并在 `420 × 720` 基础画布中按参考图顺序排列：

```swift
VStack(spacing: plan.spacing) {
    dashboardHeader.frame(height: plan.headerHeight)
    weeklyQuotaSection.frame(height: plan.quotaHeight)
    dailyActivitySection.frame(height: plan.dailyHeight)
    projectAnalyticsSection.frame(height: plan.projectHeight)
    statisticsSection.frame(height: plan.statisticsHeight)
    githubSection.frame(height: plan.githubHeight)
    dashboardFooter.frame(height: plan.footerHeight)
}
.padding(plan.padding)
.frame(width: 420, height: 720)
.scaleEffect(scale, anchor: .topLeading)
```

删除当前三行 `HStack` 网格，不加入 `ScrollView`。

- [ ] **步骤 6：运行布局与组合测试**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/private/tmp/codex-monitor-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-monitor-module-cache \
  xcrun swift test --disable-sandbox \
  --filter 'MenuPopoverLayoutTests|MenuDashboardCompositionTests|LayoutContractTests'
```

预期：目标尺寸、等比缩放、单列顺序和总高度测试通过。

- [ ] **步骤 7：提交**

```bash
git add Sources/CodexMonitor/MenuBar/MenuPopoverLayout.swift \
  Sources/CodexMonitor/MenuBar/MenuDashboardView.swift \
  Sources/CodexMonitor/MenuBar/MenuDashboardComponents.swift \
  Tests/CodexMonitorTests/MenuPopoverLayoutTests.swift \
  Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift \
  Tests/CodexMonitorTests/LayoutContractTests.swift
git commit -m "布局：建立参考图等比缩放画布"
```

---

### 任务三：实现每日活动和项目分析参考图样式

**文件：**

- 修改：`Sources/CodexMonitor/MenuBar/MenuDailyActivitySection.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuProjectAnalyticsSection.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuDashboardView.swift`
- 修改：`Tests/CodexMonitorTests/VisualFeedbackTests.swift`
- 修改：`Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift`

**接口：**

- 产出：`MenuActivityGrid.days(from:calendar:today:) -> [UsageDay]`
- 产出：`MenuDailyTokenBarPlan.make(days:) -> [MenuDailyTokenBar]`
- 消费：`MonitorSnapshot.dailyActivity`
- 消费：`ProjectAnalyticsSnapshot.period(for:)`

- [ ] **步骤 1：编写活动网格和七日柱状图失败测试**

```swift
func testReferenceActivityGridBuildsSixteenWeeks() {
    let days = MenuActivityGrid.days(from: [])
    XCTAssertEqual(days.count, 112)
}

func testDailyTokenBarsKeepLastSevenCalendarDays() {
    let days = (0..<9).map {
        UsageDay(
            date: Date(timeIntervalSince1970: Double($0 * 86_400)),
            tokens: ($0 + 1) * 100,
            sessions: 1
        )
    }
    let bars = MenuDailyTokenBarPlan.make(days: days)
    XCTAssertEqual(bars.map(\.tokens), [300, 400, 500, 600, 700, 800, 900])
}
```

- [ ] **步骤 2：运行测试并确认新规划类型缺失**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/private/tmp/codex-monitor-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-monitor-module-cache \
  xcrun swift test --disable-sandbox \
  --filter 'VisualFeedbackTests|MenuDashboardCompositionTests'
```

预期：编译失败，提示 `MenuActivityGrid` 和 `MenuDailyTokenBarPlan` 不存在。

- [ ] **步骤 3：实现每日活动参考卡片**

- 使用 16 列 × 7 行活动格填满参考图左侧区域。
- 显示周一、周三、周五、周日行标签和颜色图例。
- 右侧使用四行指标和 SF Symbols 图标。
- 中间保留竖向分隔线。
- 活动格悬停继续调用 `ActivityTooltip`。
- 无本地数据时显示现有空状态，不改变卡片高度。

- [ ] **步骤 4：实现项目分析参考卡片**

- 标题左侧显示当前范围，右侧保留全区域可点击的分段按钮。
- 左侧显示最近七个自然日 Token 柱状图和星期标签。
- 右侧显示当前范围 Token 排名前三项目。
- 排名列标题为项目、Token 总数。
- 鼠标进入排名行时显示紫色透明背景和细边框。
- 鼠标离开时恢复透明背景。
- 继续遵循“减少动态效果”设置。

- [ ] **步骤 5：运行活动和项目测试**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/private/tmp/codex-monitor-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-monitor-module-cache \
  xcrun swift test --disable-sandbox \
  --filter 'VisualFeedbackTests|MenuDashboardCompositionTests'
```

预期：112 格活动计划、最近七日柱状图、排名和既有悬停测试通过。

- [ ] **步骤 6：提交**

```bash
git add Sources/CodexMonitor/MenuBar/MenuDailyActivitySection.swift \
  Sources/CodexMonitor/MenuBar/MenuProjectAnalyticsSection.swift \
  Sources/CodexMonitor/MenuBar/MenuDashboardView.swift \
  Tests/CodexMonitorTests/VisualFeedbackTests.swift \
  Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift
git commit -m "界面：还原参考图活动与项目模块"
```

---

### 任务四：实现额度、统计和 GitHub 参考图样式

**文件：**

- 修改：`Sources/CodexMonitor/MenuBar/MenuDashboardView.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuDashboardComponents.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuWeeklyQuotaSection.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuStatisticsSection.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuGitHubActivitySection.swift`
- 修改：`Sources/CodexMonitor/GitHub/RecentRepositoryGrid.swift`
- 修改：`Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift`
- 修改：`Tests/CodexMonitorTests/GitHubModelsTests.swift`

**接口：**

- 产出：参考图顶部和底部操作栏
- 产出：五项等宽统计指标卡
- 产出：`RepositoryGridDensity.reference`
- 消费：`GitHubContributionHeatmap`
- 消费：`GitHubActivityStore.State`

- [ ] **步骤 1：为参考仓库行编写失败测试**

```swift
func testReferenceRepositoryGridUsesTwoColumnsAndThreeRows() {
    let metrics = RepositoryGridMetrics.make(density: .reference)
    XCTAssertEqual(metrics.columnCount, 2)
    XCTAssertEqual(metrics.rowCount, 3)
    XCTAssertGreaterThan(metrics.rowHeight, RepositoryGridMetrics.make(density: .compact).rowHeight)
}
```

- [ ] **步骤 2：运行 GitHub 测试并确认参考密度缺失**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/private/tmp/codex-monitor-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-monitor-module-cache \
  xcrun swift test --disable-sandbox \
  --filter 'GitHubModelsTests|MenuDashboardCompositionTests'
```

预期：编译失败，提示 `.reference` 或 `columnCount` 不存在。

- [ ] **步骤 3：实现参考图公共视觉**

- 顶部左侧使用紫色 `OpenAIKnotMark`、应用名称和更新时间。
- 顶部右侧使用两个圆形图标按钮。
- 公共卡片使用统一深色背景、细边框、参考图圆角和内边距。
- 底部左侧显示自动刷新说明，右侧显示刷新、`⌘R`、退出和 `⌘Q`。

- [ ] **步骤 4：实现本周额度和统计总览**

- 本周额度严格使用左侧大号剩余百分比、右侧已用进度和重置时间。
- 标题行复用额度新鲜状态显示 `已同步` 或 `等待 Codex 更新`。
- 统计总览横向显示五张等宽卡片，每张包含 SF Symbol、紫色数值和标签。

- [ ] **步骤 5：实现 GitHub 全宽卡片**

- 顶部显示标题、用户名和绿色连接点。
- 贡献数位于左侧，年度热力图位于右侧。
- 热力图周围显示月份、星期和颜色图例。
- 仓库网格使用 `.reference` 密度，两列三行。
- 仓库行显示 GitHub 图标、名称、更新时间和外链图标。
- 授权、刷新、断开绑定和安全链接规则保持不变。

- [ ] **步骤 6：运行菜单和 GitHub 测试**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/private/tmp/codex-monitor-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-monitor-module-cache \
  xcrun swift test --disable-sandbox \
  --filter 'MenuDashboardCompositionTests|GitHubModelsTests|GitHubActivityStoreTests'
```

预期：额度状态、五项统计、两列三行仓库和 GitHub 既有行为全部通过。

- [ ] **步骤 7：提交**

```bash
git add Sources/CodexMonitor/MenuBar \
  Sources/CodexMonitor/GitHub/RecentRepositoryGrid.swift \
  Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift \
  Tests/CodexMonitorTests/GitHubModelsTests.swift
git commit -m "界面：还原参考图额度统计与 GitHub 模块"
```

---

### 任务五：更新自动刷新、版本并生成最终安装包

**文件：**

- 修改：`Sources/CodexMonitor/App/AppDelegate.swift`
- 修改：`Resources/Info.plist`
- 修改：`Tests/CodexMonitorTests/AppIntegrationTests.swift`

**接口：**

- 周期刷新间隔：`300` 秒
- 版本：`0.1.15`
- 构建号：`16`

- [ ] **步骤 1：更新自动刷新和版本失败测试**

```swift
XCTAssertEqual(plist["CFBundleShortVersionString"] as? String, "0.1.15")
XCTAssertEqual(plist["CFBundleVersion"] as? String, "16")
```

应用刷新集成测试期望 `Timer.publish(every: 300`。目录监听仍会在本地文件变化时立即触发刷新。

- [ ] **步骤 2：运行应用集成测试并确认失败**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/private/tmp/codex-monitor-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-monitor-module-cache \
  xcrun swift test --disable-sandbox --filter AppIntegrationTests
```

预期：当前仍为 30 秒和 `0.1.14 (15)`。

- [ ] **步骤 3：更新刷新间隔和版本**

- `AppDelegate` 周期定时器改为 300 秒。
- `Resources/Info.plist` 改为 `0.1.15 (16)`。
- 菜单底部文案显示 `数据每 5 分钟自动刷新`。

- [ ] **步骤 4：运行完整测试**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/private/tmp/codex-monitor-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-monitor-module-cache \
  xcrun swift test --disable-sandbox
```

预期：全部测试通过，0 失败。

- [ ] **步骤 5：提交**

```bash
git add Sources/CodexMonitor/App/AppDelegate.swift \
  Sources/CodexMonitor/MenuBar/MenuDashboardView.swift \
  Resources/Info.plist \
  Tests/CodexMonitorTests/AppIntegrationTests.swift
git commit -m "构建：更新参考图菜单面板版本"
```

- [ ] **步骤 6：重新打包并校验签名**

```bash
bash scripts/package-app.sh
codesign --verify --deep --strict --verbose=2 "dist/Codex Monitor.app"
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
  "dist/Codex Monitor.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" \
  "dist/Codex Monitor.app/Contents/Info.plist"
```

预期：签名有效，版本为 `0.1.15`，构建号为 `16`。
