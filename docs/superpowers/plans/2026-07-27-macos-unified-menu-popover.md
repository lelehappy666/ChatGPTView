# macOS 菜单栏单页下拉面板实现计划

> **供智能代理执行：** 必须使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans`，按照任务逐项实现。所有步骤使用复选框跟踪。

**目标：** 将菜单栏原生文字菜单和刘海分页窗口替换为一个包含全部五个数据模块的 macOS 单页下拉面板。

**架构：** `MenuBarController` 使用临时型 `NSPopover` 锚定现有状态栏按钮，SwiftUI 根视图 `MenuDashboardView` 在一个纵向滚动容器中组合五个独立模块。现有 `MonitorStore`、数据格式化、GitHub 缓存和热力图策略继续复用，GitHub 网络请求在面板出现后异步加载。

**技术栈：** Swift 6.2、SwiftUI、AppKit、Combine、XCTest、macOS 14。

## 全局约束

- 所有文档和 Git 提交信息使用中文。
- 直接在 `main` 分支工作。
- 菜单栏状态文字和项目轮播保持现状。
- 五个数据模块必须位于同一个纵向页面，不允许分页、横向滑动、侧边导航或轮播圆点。
- 目标面板宽度为 `720 pt`，目标高度为 `840 pt`，实际高度不得超过屏幕可用高度减去 `24 pt`。
- 小屏幕仅允许纵向滚动，不允许横向滚动。
- 点击面板外部自动关闭；再次点击菜单栏状态区域也会关闭。
- 面板显示不能等待 GitHub 网络请求。
- “7 天”“30 天”“全部”的完整胶囊区域都必须响应点击。
- 遵循现有“减少动态效果”、额度新鲜度、GitHub 授权和安全链接策略。

---

## 文件结构

### 新增

- `Sources/CodexMonitor/MenuBar/MenuPopoverLayout.swift`：面板尺寸和打开刷新策略。
- `Sources/CodexMonitor/MenuBar/MenuDashboardView.swift`：单页根视图、顶部状态栏和底部操作栏。
- `Sources/CodexMonitor/MenuBar/MenuDashboardComponents.swift`：统一卡片、模块标题和视觉常量。
- `Sources/CodexMonitor/MenuBar/MenuWeeklyQuotaSection.swift`：本周额度模块。
- `Sources/CodexMonitor/MenuBar/MenuDailyActivitySection.swift`：每日活动模块。
- `Sources/CodexMonitor/MenuBar/MenuProjectAnalyticsSection.swift`：项目分析模块。
- `Sources/CodexMonitor/MenuBar/MenuStatisticsSection.swift`：统计总览模块。
- `Sources/CodexMonitor/MenuBar/MenuGitHubActivitySection.swift`：GitHub 状态、授权和活动模块。
- `Tests/CodexMonitorTests/MenuPopoverLayoutTests.swift`：面板尺寸与打开刷新策略测试。
- `Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift`：模块顺序、项目图表规划和 GitHub 展示状态测试。

### 修改

- `Sources/CodexMonitor/MenuBar/MenuBarController.swift`：用 `NSPopover` 替换 `NSMenu`。
- `Sources/CodexMonitor/GitHub/GitHubActivityPage.swift`：把授权卡和 GitHub 内容组件调整为可复用的内部组件。
- `Sources/CodexMonitor/App/AppDelegate.swift`：停止创建刘海窗口。
- `Tests/CodexMonitorTests/AppIntegrationTests.swift`：删除不再适用的刘海分页测试并更新版本断言。
- `Tests/CodexMonitorTests/LayoutContractTests.swift`：改为验证菜单面板布局。
- `Resources/Info.plist`：版本更新为 `0.1.13 (14)`。

### 保留但不再启动

- `Sources/CodexMonitor/Notch/` 下的旧页面和控制器暂时保留，避免本次 UI 迁移夹带无关的大规模删除；`AppDelegate` 不再引用它们，因此运行时不会安装全局鼠标监听或显示刘海窗口。

---

### 任务一：建立面板尺寸与打开刷新策略

**文件：**

- 新增：`Sources/CodexMonitor/MenuBar/MenuPopoverLayout.swift`
- 新增：`Tests/CodexMonitorTests/MenuPopoverLayoutTests.swift`

**接口：**

- 产出：`MenuPopoverLayout.contentSize(for visibleFrame: CGRect) -> CGSize`
- 产出：`MenuPopoverOpenPolicy.shouldRefresh(isShown: Bool) -> Bool`
- 后续任务由 `MenuBarController` 消费两个策略。

- [ ] **步骤 1：编写失败的布局测试**

```swift
import XCTest
@testable import CodexMonitor

final class MenuPopoverLayoutTests: XCTestCase {
    func testUsesTargetSizeWhenScreenHasEnoughSpace() {
        let size = MenuPopoverLayout.contentSize(
            for: CGRect(x: 0, y: 0, width: 1440, height: 1000)
        )
        XCTAssertEqual(size, CGSize(width: 720, height: 840))
    }

    func testClampsHeightAndWidthToVisibleScreen() {
        let size = MenuPopoverLayout.contentSize(
            for: CGRect(x: 0, y: 0, width: 700, height: 760)
        )
        XCTAssertEqual(size, CGSize(width: 676, height: 736))
    }

    func testOpeningHiddenPopoverRequestsRefresh() {
        XCTAssertTrue(MenuPopoverOpenPolicy.shouldRefresh(isShown: false))
        XCTAssertFalse(MenuPopoverOpenPolicy.shouldRefresh(isShown: true))
    }
}
```

- [ ] **步骤 2：运行测试并确认失败**

运行：

```bash
swift test --filter MenuPopoverLayoutTests
```

预期：因 `MenuPopoverLayout` 和 `MenuPopoverOpenPolicy` 尚未定义而编译失败。

- [ ] **步骤 3：实现面板布局策略**

```swift
import Foundation

enum MenuPopoverLayout {
    static let targetSize = CGSize(width: 720, height: 840)
    static let screenInset: CGFloat = 24

    static func contentSize(for visibleFrame: CGRect) -> CGSize {
        CGSize(
            width: min(targetSize.width, visibleFrame.width - screenInset),
            height: min(targetSize.height, visibleFrame.height - screenInset)
        )
    }
}

enum MenuPopoverOpenPolicy {
    static func shouldRefresh(isShown: Bool) -> Bool {
        !isShown
    }
}
```

- [ ] **步骤 4：运行布局测试**

运行：

```bash
swift test --filter MenuPopoverLayoutTests
```

预期：3 个测试全部通过。

- [ ] **步骤 5：提交**

```bash
git add Sources/CodexMonitor/MenuBar/MenuPopoverLayout.swift \
  Tests/CodexMonitorTests/MenuPopoverLayoutTests.swift
git commit -m "功能：增加菜单面板布局策略"
```

---

### 任务二：实现单页骨架、本周额度、每日活动和统计总览

**文件：**

- 新增：`Sources/CodexMonitor/MenuBar/MenuDashboardView.swift`
- 新增：`Sources/CodexMonitor/MenuBar/MenuDashboardComponents.swift`
- 新增：`Sources/CodexMonitor/MenuBar/MenuWeeklyQuotaSection.swift`
- 新增：`Sources/CodexMonitor/MenuBar/MenuDailyActivitySection.swift`
- 新增：`Sources/CodexMonitor/MenuBar/MenuStatisticsSection.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuBarController.swift`
- 新增：`Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift`

**接口：**

- 消费：`MonitorStore.snapshot`、`MonitorStore.refreshState`、`MonitorStore.requestRefresh()`
- 产出：`MenuDashboardView.init(store:onClose:onQuit:)`
- 产出：`MenuDashboardSectionCard` 和 `MenuDashboardSectionHeader`
- 产出：`MenuDashboardComposition.sections: [MenuDashboardSection]`

- [ ] **步骤 1：编写单页模块组合行为测试**

测试根视图实际消费的模块组合模型，验证顺序且不会重复：

```swift
XCTAssertEqual(
    MenuDashboardComposition.sections,
    [.weeklyQuota, .dailyActivity, .projectAnalytics, .statistics, .github]
)
XCTAssertEqual(Set(MenuDashboardComposition.sections).count, 5)
```

- [ ] **步骤 2：运行契约测试并确认失败**

运行：

```bash
swift test --filter MenuDashboardCompositionTests
```

预期：因 `MenuDashboardComposition` 尚未定义而编译失败。

- [ ] **步骤 3：实现统一视觉组件**

`MenuDashboardComponents.swift` 提供：

```swift
struct MenuDashboardSectionCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
}

struct MenuDashboardSectionHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: () -> Trailing
}

enum MenuDashboardVisual {
    static let accent = Color(red: 0.66, green: 0.59, blue: 0.95)
    static let success = Color(red: 0.49, green: 0.90, blue: 0.73)
}
```

卡片使用深色半透明背景、`16 pt` 圆角、细白色描边，不使用离屏模糊。

- [ ] **步骤 4：实现单页根视图**

根视图使用以下固定顺序：

```swift
ScrollView(.vertical, showsIndicators: false) {
    LazyVStack(spacing: 12) {
        ForEach(MenuDashboardComposition.sections, id: \.self) { section in
            sectionView(for: section)
        }
    }
    .padding(20)
}
```

项目分析和 GitHub 在本任务中先复用现有页面，任务三、任务四再分别替换为适配宽面板的模块。顶部显示应用名、最近刷新状态、刷新按钮和收起按钮；底部显示自动刷新说明、“刷新数据 ⌘R”和“退出 ⌘Q”。根视图强制深色外观并遵循 `accessibilityReduceMotion`。

- [ ] **步骤 5：实现本周额度模块**

- 复用 `QuotaFreshnessPolicy` 和 `QuotaRefreshPresentation`。
- 显示剩余额度、本周已用进度和距离重置时间。
- 刷新按钮的整个胶囊区域响应点击。
- 每 30 秒更新额度新鲜度展示，不主动触发磁盘扫描。

- [ ] **步骤 6：实现每日活动模块**

- 复用 `ActivityHeatmap` 和 `ActivityTooltip`。
- 左侧显示最近八周热力图。
- 右侧显示今日 Token、会话、平均/天和连续使用天数。
- 热力图保留鼠标悬停详情。

- [ ] **步骤 7：实现统计总览模块**

用五个等宽指标卡展示累计 Token、峰值 Token、最长任务时长、当前连续天数和最长连续天数，继续使用 `MetricFormatter`。

- [ ] **步骤 8：将原生菜单替换为临时型 `NSPopover`**

在 `MenuBarController` 中：

- 删除 `NSMenu`、`refreshItem` 和 `updateRefreshItem`。
- 创建 `NSPopover`，设置 `behavior = .transient` 和 `animates = true`。
- 为状态栏按钮设置 `target`、`action` 和 `sendAction(on: [.leftMouseUp])`。
- `togglePopover(_:)` 根据当前屏幕 `visibleFrame` 更新 `contentSize`。
- 打开前调用 `store.requestRefresh()`，然后使用 `show(relativeTo:of:preferredEdge:)`。
- 关闭时调用 `performClose(nil)`。

```swift
let rootView = MenuDashboardView(
    store: store,
    onClose: { [weak self] in self?.popover.performClose(nil) },
    onQuit: { NSApp.terminate(nil) }
)
popover.contentViewController = NSHostingController(rootView: rootView)
```

- [ ] **步骤 9：运行集成测试和构建**

运行：

```bash
swift test --filter MenuDashboardCompositionTests
swift build
```

预期：测试通过，应用目标编译成功。

- [ ] **步骤 10：提交**

```bash
git add Sources/CodexMonitor/MenuBar/MenuDashboardView.swift \
  Sources/CodexMonitor/MenuBar/MenuDashboardComponents.swift \
  Sources/CodexMonitor/MenuBar/MenuWeeklyQuotaSection.swift \
  Sources/CodexMonitor/MenuBar/MenuDailyActivitySection.swift \
  Sources/CodexMonitor/MenuBar/MenuStatisticsSection.swift \
  Sources/CodexMonitor/MenuBar/MenuBarController.swift \
  Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift
git commit -m "功能：构建菜单栏单页数据总览"
```

---

### 任务三：实现项目分析模块和完整范围按钮

**文件：**

- 新增：`Sources/CodexMonitor/MenuBar/MenuProjectAnalyticsSection.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuDashboardView.swift`
- 修改：`Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift`

**接口：**

- 消费：`ProjectAnalyticsSnapshot.period(for:)`
- 消费：`ProjectAnalyticsRange.sevenDays`、`.thirtyDays`、`.all`
- 产出：`MenuProjectAnalyticsSection.init(analytics:reduceMotion:)`
- 产出：`ProjectAnalyticsBarPlan.make(rows:) -> [ProjectAnalyticsBar]`

- [ ] **步骤 1：编写项目图表规划行为测试**

用固定项目验证图表保持排名顺序，并按最大 Token 归一化柱长：

```swift
let rows = [
    ProjectAnalyticsRow(
        id: "a", name: "A", tokens: 100,
        sessions: 2, activeDays: 1, share: 2.0 / 3.0
    ),
    ProjectAnalyticsRow(
        id: "b", name: "B", tokens: 50,
        sessions: 1, activeDays: 1, share: 1.0 / 3.0
    )
]
XCTAssertEqual(
    ProjectAnalyticsBarPlan.make(rows: rows).map(\.relativeHeight),
    [1.0, 0.5]
)
```

- [ ] **步骤 2：运行测试并确认失败**

运行：

```bash
swift test --filter MenuDashboardCompositionTests
```

预期：因 `ProjectAnalyticsBarPlan` 尚未定义而编译失败。

- [ ] **步骤 3：实现项目分析布局**

- 使用本地 `@State private var selectedRange: ProjectAnalyticsRange = .sevenDays`。
- 顶部放置“7 天”“30 天”“全部”三个按钮。
- 按钮标签先设置 `.frame(minWidth: 58, minHeight: 28)`，再设置 `.contentShape(Rectangle())`。
- 左侧根据 `ProjectAnalyticsBarPlan` 绘制紧凑柱状图并显示鼠标悬停详情。
- 右侧显示 Token 排名前五的项目、总量和占比。
- 切换范围时清理悬停状态；减少动态效果开启时不使用过渡动画。

- [ ] **步骤 4：运行相关测试和构建**

运行：

```bash
swift test --filter MenuDashboardCompositionTests
swift build
```

预期：测试通过，项目分析模块编译成功。

- [ ] **步骤 5：提交**

```bash
git add Sources/CodexMonitor/MenuBar/MenuProjectAnalyticsSection.swift \
  Sources/CodexMonitor/MenuBar/MenuDashboardView.swift \
  Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift
git commit -m "功能：增加单页项目分析模块"
```

---

### 任务四：整合 GitHub 活跃、授权和最近仓库

**文件：**

- 新增：`Sources/CodexMonitor/MenuBar/MenuGitHubActivitySection.swift`
- 修改：`Sources/CodexMonitor/GitHub/GitHubActivityPage.swift`
- 修改：`Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift`

**接口：**

- 消费：`GitHubActivityStore.State`
- 消费：`GitHubContributionHeatmap`、`RecentRepositoryGrid`
- 产出：可复用的 `GitHubAuthorizationCard`
- 产出：`MenuGitHubActivitySection.init(store:)`
- 产出：`GitHubMenuPresentation.make(state:)`

- [ ] **步骤 1：编写 GitHub 面板状态映射测试**

测试存储状态映射到授权或内容展示：

```swift
XCTAssertEqual(
    GitHubMenuPresentation.make(state: .unbound(message: nil)),
    .authorization(message: nil)
)
XCTAssertEqual(
    GitHubMenuPresentation.make(state: .loading(cached: snapshot)),
    .content(snapshot: snapshot, statusMessage: "正在刷新")
)
XCTAssertEqual(
    GitHubMenuPresentation.make(state: .loaded(snapshot)),
    .content(snapshot: snapshot, statusMessage: nil)
)
XCTAssertEqual(
    GitHubMenuPresentation.make(
        state: .failed(message: "网络错误", cached: snapshot)
    ),
    .content(snapshot: snapshot, statusMessage: "网络错误")
)
```

- [ ] **步骤 2：运行测试并确认失败**

运行：

```bash
swift test --filter MenuDashboardCompositionTests
```

预期：因 `GitHubMenuPresentation` 尚未定义而编译失败。

- [ ] **步骤 3：提取可复用的授权卡**

将 `GitHubAuthorizationCard` 从 `private` 调整为模块内部可见，保留：

- 从剪贴板读取令牌。
- 未找到令牌时打开 GitHub 令牌页面。
- 绑定时调用异步 `onBind`。
- 隐私说明和失败消息。

不得复制钥匙串读写或授权判断逻辑。

- [ ] **步骤 4：实现单页 GitHub 模块**

根据 `store.state` 显示：

- `.unbound`：模块内部的紧凑授权卡。
- `.loading(cached:)`：优先显示缓存和刷新状态；无缓存时显示进度。
- `.loaded`：贡献总数、贡献热力图、用户名和六个最近仓库。
- `.failed(message:cached:)`：保留缓存并显示错误；无缓存时显示授权卡。

刷新按钮调用 `Task { await store.refresh() }`；用户名按钮的右键菜单保留“解除绑定”。

- [ ] **步骤 5：在根视图出现后异步加载 GitHub**

```swift
.onAppear {
    githubStore.primeFromCache()
}
.task {
    await githubStore.loadIfNeeded()
}
```

根视图必须先渲染本地模块，再执行异步加载。

- [ ] **步骤 6：运行 GitHub 与集成测试**

运行：

```bash
swift test --filter GitHub
swift test --filter MenuDashboardCompositionTests
```

预期：GitHub 状态测试和单页契约全部通过。

- [ ] **步骤 7：提交**

```bash
git add Sources/CodexMonitor/MenuBar/MenuGitHubActivitySection.swift \
  Sources/CodexMonitor/MenuBar/MenuDashboardView.swift \
  Sources/CodexMonitor/GitHub/GitHubActivityPage.swift \
  Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift
git commit -m "功能：整合单页 GitHub 活跃模块"
```

---

### 任务五：停用刘海窗口、更新版本并完成打包

**文件：**

- 修改：`Sources/CodexMonitor/App/AppDelegate.swift`
- 修改：`Tests/CodexMonitorTests/AppIntegrationTests.swift`
- 修改：`Tests/CodexMonitorTests/LayoutContractTests.swift`
- 修改：`Resources/Info.plist`

**接口：**

- `AppDelegate` 只保留 `MenuBarController` 作为数据面板入口。
- `MenuPopoverLayout` 替代旧的 `NotchLayout` 运行时契约。

- [ ] **步骤 1：用新布局行为测试替换旧刘海尺寸测试**

将 `LayoutContractTests` 中的刘海尺寸和分页延迟测试替换为对屏幕适配结果的断言：

```swift
XCTAssertEqual(
    MenuPopoverLayout.contentSize(
        for: CGRect(x: 0, y: 0, width: 800, height: 700)
    ),
    CGSize(width: 720, height: 676)
)
```

- [ ] **步骤 2：运行测试并确认失败**

运行：

```bash
swift test --filter LayoutContractTests
```

预期：旧测试仍断言刘海尺寸，新的屏幕适配断言尚未加入。

- [ ] **步骤 3：停用刘海窗口**

从 `AppDelegate` 删除：

- `notchWindowController` 属性。
- `NotchWindowController(store:)` 的创建和 `start()`。
- `applicationWillTerminate` 中的 `stop()`。

保留会话目录监听、通知、30 秒自动刷新和唤醒刷新。

- [ ] **步骤 4：更新版本**

把 `Resources/Info.plist` 更新为：

```xml
<key>CFBundleShortVersionString</key>
<string>0.1.13</string>
<key>CFBundleVersion</key>
<string>14</string>
```

同步更新 `AppIntegrationTests.testAppMetadataDeclaresPackagedIcon` 的版本期望。

- [ ] **步骤 5：运行完整测试**

运行：

```bash
swift test
```

预期：全部 XCTest 通过，失败数为 0。

- [ ] **步骤 6：提交**

```bash
git add Sources/CodexMonitor/App/AppDelegate.swift \
  Tests/CodexMonitorTests/AppIntegrationTests.swift \
  Tests/CodexMonitorTests/LayoutContractTests.swift \
  Resources/Info.plist
git commit -m "功能：启用菜单栏单页下拉面板"
```

- [ ] **步骤 7：生成稳定签名应用包**

运行：

```bash
bash scripts/package-app.sh
```

预期输出包含：

```text
dist/Codex Monitor.app: valid on disk
dist/Codex Monitor.app: satisfies its Designated Requirement
```

- [ ] **步骤 8：验证最终应用包**

运行：

```bash
codesign --verify --deep --strict --verbose=2 "dist/Codex Monitor.app"
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
  "dist/Codex Monitor.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" \
  "dist/Codex Monitor.app/Contents/Info.plist"
```

预期：签名有效，版本为 `0.1.13`，构建号为 `14`。

- [ ] **步骤 9：执行真实界面冒烟验证**

- 启动新打包的应用。
- 把鼠标移动到屏幕刘海区域，确认不再出现旧刘海分页窗口。
- 点击菜单栏 Codex Monitor 状态区域，确认出现单页下拉面板。
- 确认五个模块在同一纵向页面中，项目范围按钮可点击，面板外点击可关闭。
- 关闭应用，避免影响后续用户自行验证。
