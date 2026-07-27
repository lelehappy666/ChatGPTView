# macOS 额度手动刷新实施计划

> **面向代理执行者：** 必须使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans`，按任务逐项实施。本计划使用复选框跟踪进度。

**目标：** 将周额度页面右上角状态改为始终可点击的手动刷新按钮，并展示刷新中、失败、等待和已同步状态。

**架构：** 新增纯值类型 `QuotaRefreshPresentation` 统一计算按钮文案、启用状态和进度状态。`NotchRootView` 只把 `MonitorStore` 的刷新状态与刷新闭包，经 `NotchDashboardView` 传递到 `WeeklyQuotaPage`；页面不直接依赖整个 Store。

**技术栈：** Swift 6.2、SwiftUI、Combine、XCTest、Swift Package Manager。

## 全局约束

- 仅修改 macOS 版本，不修改 Windows 版本。
- 手动刷新只重新扫描 `~/.codex/sessions`，不得新增未公开的 Codex 服务接口。
- 保留每30秒自动刷新和5分钟额度新鲜度规则。
- 刷新失败时保留上一次快照。
- 所有文档和 Git 提交使用中文。
- 直接在 `main` 分支工作。

---

### 任务一：额度刷新按钮展示策略

**文件：**

- 新建：`Sources/CodexMonitor/Notch/QuotaRefreshPresentation.swift`
- 新建：`Tests/CodexMonitorTests/QuotaRefreshPresentationTests.swift`

**接口：**

- 输入：`RefreshState`、是否存在原始额度、额度是否新鲜。
- 输出：`QuotaRefreshPresentation.make(refreshState:hasQuota:isFresh:) -> QuotaRefreshPresentation`
- 属性：`title: String`、`isEnabled: Bool`、`showsProgress: Bool`

- [ ] **步骤1：编写失败测试**

```swift
import XCTest
@testable import CodexMonitor

final class QuotaRefreshPresentationTests: XCTestCase {
    func testRefreshingDisablesButtonAndShowsProgress() {
        let value = QuotaRefreshPresentation.make(
            refreshState: .refreshing,
            hasQuota: true,
            isFresh: false
        )

        XCTAssertEqual(value.title, "正在刷新…")
        XCTAssertFalse(value.isEnabled)
        XCTAssertTrue(value.showsProgress)
    }

    func testFreshQuotaIsRefreshable() {
        let value = QuotaRefreshPresentation.make(
            refreshState: .updated,
            hasQuota: true,
            isFresh: true
        )

        XCTAssertEqual(value.title, "已同步")
        XCTAssertTrue(value.isEnabled)
        XCTAssertFalse(value.showsProgress)
    }

    func testStaleQuotaRemainsRefreshable() {
        let value = QuotaRefreshPresentation.make(
            refreshState: .idle,
            hasQuota: true,
            isFresh: false
        )

        XCTAssertEqual(value.title, "等待 Codex 更新")
        XCTAssertTrue(value.isEnabled)
    }

    func testUnavailableAndFailureRemainRefreshable() {
        XCTAssertEqual(
            QuotaRefreshPresentation.make(
                refreshState: .idle,
                hasQuota: false,
                isFresh: false
            ).title,
            "暂不可用"
        )
        XCTAssertEqual(
            QuotaRefreshPresentation.make(
                refreshState: .failed,
                hasQuota: true,
                isFresh: false
            ).title,
            "刷新失败"
        )
    }
}
```

- [ ] **步骤2：运行测试并确认正确失败**

运行：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/tmp/codex-monitor-clang-cache \
SWIFT_MODULECACHE_PATH=/tmp/codex-monitor-swift-cache \
xcrun swift test --disable-sandbox \
  --filter QuotaRefreshPresentationTests
```

预期：编译失败，提示找不到 `QuotaRefreshPresentation`。

- [ ] **步骤3：实现最小展示策略**

```swift
struct QuotaRefreshPresentation: Equatable {
    let title: String
    let isEnabled: Bool
    let showsProgress: Bool

    static func make(
        refreshState: RefreshState,
        hasQuota: Bool,
        isFresh: Bool
    ) -> Self {
        if refreshState == .refreshing {
            return Self(
                title: "正在刷新…",
                isEnabled: false,
                showsProgress: true
            )
        }
        if refreshState == .failed {
            return Self(
                title: "刷新失败",
                isEnabled: true,
                showsProgress: false
            )
        }
        if !hasQuota {
            return Self(
                title: "暂不可用",
                isEnabled: true,
                showsProgress: false
            )
        }
        return Self(
            title: isFresh ? "已同步" : "等待 Codex 更新",
            isEnabled: true,
            showsProgress: false
        )
    }
}
```

- [ ] **步骤4：运行目标测试并确认通过**

运行步骤2中的命令。

预期：`QuotaRefreshPresentationTests` 全部通过。

- [ ] **步骤5：提交**

```bash
git add Sources/CodexMonitor/Notch/QuotaRefreshPresentation.swift \
  Tests/CodexMonitorTests/QuotaRefreshPresentationTests.swift
git commit -m "功能：增加额度刷新状态策略"
```

---

### 任务二：接通刷新调用链

**文件：**

- 修改：`Sources/CodexMonitor/Notch/NotchWindowController.swift`
- 修改：`Sources/CodexMonitor/Notch/NotchDashboardView.swift`
- 修改：`Sources/CodexMonitor/Notch/WeeklyQuotaPage.swift`

**接口：**

- `NotchDashboardView` 新增 `refreshState: RefreshState`
- `NotchDashboardView` 新增 `onRefreshQuota: () -> Void`
- `WeeklyQuotaPage` 新增 `refreshState: RefreshState`
- `WeeklyQuotaPage` 新增 `onRefresh: () -> Void`
- `NotchRootView` 传入 `store.refreshState` 与 `store.requestRefresh`

本任务只接通 SwiftUI 声明式视图的输入，不新增只检查源码文字的变化探测测试。按钮状态行为由任务一的真实值类型测试覆盖，Store 刷新行为由现有 `MonitorStoreTests` 覆盖；本任务通过 Swift 编译和这两组行为测试验证集成。

- [ ] **步骤1：修改 `NotchRootView`**

将根视图改为：

```swift
private struct NotchRootView: View {
    @ObservedObject var store: MonitorStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NotchDashboardView(
            snapshot: store.snapshot,
            refreshState: store.refreshState,
            reduceMotion: reduceMotion,
            onRefreshQuota: store.requestRefresh
        )
    }
}
```

- [ ] **步骤2：修改 `NotchDashboardView`**

增加输入：

```swift
let snapshot: MonitorSnapshot
let refreshState: RefreshState
let reduceMotion: Bool
let onRefreshQuota: () -> Void
```

第一页改为：

```swift
WeeklyQuotaPage(
    snapshot: snapshot,
    refreshState: refreshState,
    onRefresh: onRefreshQuota
)
```

- [ ] **步骤3：把周额度状态区改为按钮**

在 `WeeklyQuotaPage` 增加：

```swift
let refreshState: RefreshState
let onRefresh: () -> Void
@State private var isRefreshHovered = false

private var presentation: QuotaRefreshPresentation {
    .make(
        refreshState: refreshState,
        hasQuota: snapshot.weeklyQuota.remainingPercent != nil,
        isFresh: remaining != nil
    )
}
```

将顶部标题改为页面内专用 `HStack`，右侧使用：

```swift
Button(action: onRefresh) {
    HStack(spacing: 4) {
        if presentation.showsProgress {
            ProgressView()
                .controlSize(.mini)
        } else {
            Image(systemName: "arrow.clockwise")
        }
        Text(presentation.title)
    }
    .font(.system(size: 10, weight: .medium))
    .foregroundStyle(Color(red: 0.49, green: 0.90, blue: 0.73))
    .padding(.horizontal, 7)
    .padding(.vertical, 4)
    .contentShape(Rectangle())
}
.buttonStyle(.plain)
.disabled(!presentation.isEnabled)
.background(
    Capsule()
        .fill(Color.white.opacity(isRefreshHovered ? 0.08 : 0))
)
.onHover { isRefreshHovered = $0 }
.help("立即重新扫描 Codex 本地额度数据")
```

删除原有 `syncText`。保留共享 `DashboardHeader` 供其他页面使用。

- [ ] **步骤4：编译并运行覆盖两端行为的测试**

运行：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/tmp/codex-monitor-clang-cache \
SWIFT_MODULECACHE_PATH=/tmp/codex-monitor-swift-cache \
xcrun swift test --disable-sandbox \
  --filter QuotaRefreshPresentationTests

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/tmp/codex-monitor-clang-cache \
SWIFT_MODULECACHE_PATH=/tmp/codex-monitor-swift-cache \
xcrun swift test --disable-sandbox \
  --filter MonitorStoreTests
```

预期：项目编译成功，两组行为测试全部通过。

- [ ] **步骤5：提交**

```bash
git add Sources/CodexMonitor/Notch/NotchWindowController.swift \
  Sources/CodexMonitor/Notch/NotchDashboardView.swift \
  Sources/CodexMonitor/Notch/WeeklyQuotaPage.swift
git commit -m "功能：增加周额度手动刷新按钮"
```

---

### 任务三：完整回归

**文件：**

- 验证：全部 Swift 源码与测试。

**接口：**

- 消费：任务一的 `QuotaRefreshPresentation`
- 消费：任务二的刷新闭包调用链
- 产出：可进入稳定签名与版本发布计划的已验证 macOS 应用源码

- [ ] **步骤1：运行完整测试**

```bash
set -o pipefail
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/tmp/codex-monitor-clang-cache \
SWIFT_MODULECACHE_PATH=/tmp/codex-monitor-swift-cache \
xcrun swift test --disable-sandbox 2>&1 | tail -50
```

预期：全部测试通过，0失败。

- [ ] **步骤2：检查格式与工作区**

```bash
git diff --check
git status --short --branch
```

预期：没有未提交的源码改动。
