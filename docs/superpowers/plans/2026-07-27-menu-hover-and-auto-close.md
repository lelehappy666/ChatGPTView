# 菜单面板悬停与自动收回实施计划

> **面向代理式开发者：** 必须使用 `superpowers:executing-plans` 按任务执行本计划。步骤使用复选框跟踪。

**目标：** 修复活动格悬停导致的布局变化，增加鼠标离开菜单面板后自动收回，并把参考密度仓库项改为 GitHub 标志。

**架构：** 活动悬停信息抽成固定尺寸 SwiftUI 读数视图；面板收回使用纯状态机决定取消或安排关闭任务，视图只负责 300 毫秒延迟；仓库前导图标按密度选择，参考密度使用白底深色 GitHub 标志。

**技术栈：** Swift 6.2、SwiftUI、AppKit、XCTest、Swift Package Manager。

## 全局约束

- 直接在 `main` 分支开发。
- 所有文档和 Git 提交信息使用中文。
- 原刘海五页内容和交互保持不变。
- 菜单面板继续使用 `420 × 720 pt` 等比例画布，不增加滚动。
- 活动格 Token 信息继续可见，但不使用 macOS 系统 `.help` 浮窗。
- 鼠标离开后等待 300 毫秒再关闭，重新进入必须取消关闭。

---

### 任务一：固定活动格悬停读数区域

**文件：**

- 修改：`Sources/CodexMonitor/MenuBar/MenuDailyActivitySection.swift`
- 修改：`Tests/CodexMonitorTests/VisualFeedbackTests.swift`

**接口：**

- 产出：`MenuActivityHoverReadout`
- 消费：`UsageDay?`
- 固定尺寸：`158 × 9 pt`

- [ ] **步骤 1：编写有无悬停时尺寸一致的失败测试**

```swift
@MainActor
func testMenuActivityHoverReadoutKeepsTheSameSize() {
    let day = UsageDay(
        date: Date(timeIntervalSince1970: 0),
        tokens: 100,
        sessions: 1
    )
    let idle = NSHostingView(
        rootView: MenuActivityHoverReadout(day: nil)
    ).fittingSize
    let hovered = NSHostingView(
        rootView: MenuActivityHoverReadout(day: day)
    ).fittingSize

    XCTAssertEqual(idle, CGSize(width: 158, height: 9))
    XCTAssertEqual(hovered, idle)
}
```

- [ ] **步骤 2：运行测试并确认缺少读数视图**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/private/tmp/codex-monitor-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-monitor-module-cache \
  xcrun swift test --disable-sandbox --filter VisualFeedbackTests
```

预期：编译失败，提示 `MenuActivityHoverReadout` 不存在。

- [ ] **步骤 3：实现固定读数区域**

```swift
struct MenuActivityHoverReadout: View {
    let day: UsageDay?

    var body: some View {
        Group {
            if let day {
                Text(ActivityTooltip.text(for: day))
            } else {
                MenuActivityLegend()
            }
        }
        .font(.system(size: 6.5))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .frame(width: 158, height: 9, alignment: .leading)
    }
}
```

热力格删除 `.help(ActivityTooltip.text(for: day))`，下方始终渲染 `MenuActivityHoverReadout(day: hoveredDay)`。

- [ ] **步骤 4：运行活动悬停测试**

运行步骤 2 的命令，预期全部通过。

- [ ] **步骤 5：提交**

```bash
git add Sources/CodexMonitor/MenuBar/MenuDailyActivitySection.swift \
  Tests/CodexMonitorTests/VisualFeedbackTests.swift
git commit -m "修复：稳定活动格悬停布局"
```

---

### 任务二：鼠标离开菜单面板后自动收回

**文件：**

- 修改：`Sources/CodexMonitor/MenuBar/MenuDashboardView.swift`
- 修改：`Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift`

**接口：**

- 产出：`MenuPopoverHoverState.update(isInside:) -> MenuPopoverHoverAction`
- 动作：`.none`、`.cancelClose`、`.scheduleClose`
- 延迟：300 毫秒

- [ ] **步骤 1：编写进入、离开和重新进入的失败测试**

```swift
func testPopoverAutoCloseStartsOnlyAfterPointerEntered() {
    var state = MenuPopoverHoverState()
    XCTAssertEqual(state.update(isInside: false), .none)
    XCTAssertEqual(state.update(isInside: true), .cancelClose)
    XCTAssertEqual(state.update(isInside: false), .scheduleClose)
    XCTAssertEqual(state.update(isInside: true), .cancelClose)
}
```

- [ ] **步骤 2：运行组合测试并确认类型缺失**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/private/tmp/codex-monitor-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-monitor-module-cache \
  xcrun swift test --disable-sandbox --filter MenuDashboardCompositionTests
```

预期：编译失败，提示 `MenuPopoverHoverState` 不存在。

- [ ] **步骤 3：实现状态机和延迟关闭**

```swift
enum MenuPopoverHoverAction: Equatable {
    case none
    case cancelClose
    case scheduleClose
}

struct MenuPopoverHoverState {
    private(set) var hasEntered = false

    mutating func update(isInside: Bool) -> MenuPopoverHoverAction {
        if isInside {
            hasEntered = true
            return .cancelClose
        }
        return hasEntered ? .scheduleClose : .none
    }
}
```

`MenuDashboardView` 保存状态机和关闭任务；`.onHover` 收到 `.scheduleClose` 时创建 300 毫秒任务，收到 `.cancelClose` 时取消任务；消失时取消任务。

- [ ] **步骤 4：运行组合测试**

运行步骤 2 的命令，预期全部通过。

- [ ] **步骤 5：提交**

```bash
git add Sources/CodexMonitor/MenuBar/MenuDashboardView.swift \
  Tests/CodexMonitorTests/MenuDashboardCompositionTests.swift
git commit -m "功能：菜单面板离开鼠标后自动收回"
```

---

### 任务三：替换参考仓库项 GitHub 标志并打包

**文件：**

- 修改：`Sources/CodexMonitor/GitHub/RecentRepositoryGrid.swift`
- 修改：`Tests/CodexMonitorTests/GitHubModelsTests.swift`
- 修改：`Resources/Info.plist`
- 修改：`Tests/CodexMonitorTests/AppIntegrationTests.swift`

**接口：**

- 产出：`RepositoryLeadingIcon.make(density:)`
- 参考密度：`.github`
- 其他密度：`.repository`
- 版本：`0.1.16 (17)`

- [ ] **步骤 1：编写密度选择失败测试**

```swift
func testReferenceRepositoryRowsUseGitHubMark() {
    XCTAssertEqual(
        RepositoryLeadingIcon.make(density: .reference),
        .github
    )
    XCTAssertEqual(
        RepositoryLeadingIcon.make(density: .compact),
        .repository
    )
}
```

- [ ] **步骤 2：运行 GitHub 模型测试并确认类型缺失**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/private/tmp/codex-monitor-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-monitor-module-cache \
  xcrun swift test --disable-sandbox --filter GitHubModelsTests
```

预期：编译失败，提示 `RepositoryLeadingIcon` 不存在。

- [ ] **步骤 3：实现 GitHub 标志**

```swift
enum RepositoryLeadingIcon: Equatable {
    case repository
    case github

    static func make(density: RepositoryGridDensity) -> Self {
        density == .reference ? .github : .repository
    }
}
```

参考密度使用白色圆形背景和深色 `cat.fill` Octocat 标志，其他密度继续使用 `book.closed`。

- [ ] **步骤 4：更新版本测试和版本**

- `AppIntegrationTests` 期望 `0.1.16 (17)`。
- `Resources/Info.plist` 更新为 `0.1.16 (17)`。

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
git add Sources/CodexMonitor/GitHub/RecentRepositoryGrid.swift \
  Tests/CodexMonitorTests/GitHubModelsTests.swift \
  Resources/Info.plist Tests/CodexMonitorTests/AppIntegrationTests.swift
git commit -m "构建：更新菜单悬停与自动收回版本"
```

- [ ] **步骤 7：打包并校验**

```bash
bash scripts/package-app.sh
codesign --verify --deep --strict --verbose=2 "dist/Codex Monitor.app"
```

预期：生成签名有效的 `dist/Codex Monitor.app`，版本为 `0.1.16 (17)`。
