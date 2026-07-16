# macOS 项目分析页面实施计划

> **供智能执行者使用：** 按任务顺序在当前会话内执行；用户已明确要求不运行测试，完成代码后直接进行 Release 打包。

**目标：** 在 macOS 刘海仪表盘新增第 3 页「项目分析」，以后台增量索引提供 7 天、30 天和全部范围的项目 Token 排名，并交付可运行应用包。

**架构：** `ProjectAnalyticsIndex` actor 按会话标识维护项目自然日聚合桶，刷新时只撤销和加入发生变化的会话，再一次性生成三个范围快照。`ProjectAnalyticsPage` 只读取 `MonitorSnapshot.projectAnalytics`，范围切换和鼠标悬停不访问文件系统。

**技术栈：** Swift 6.2、SwiftUI、Swift Concurrency、Swift Package Manager、macOS 14+

## 全局约束

- 项目分析页固定为第 3 页，位于「每日活动」之后；
- 页面顺序为：本周额度、每日活动、项目分析、统计总览、GitHub 活跃；
- 不增加第三方依赖、云服务或持久化数据库；
- 所有界面文案和项目文档使用中文；
- 所有 Git 提交信息使用中文；
- 本次按用户要求不新增或运行测试；
- 完成后通过 `scripts/package-app.sh` 生成 Release 应用包。

---

### 任务 1：项目分析领域模型

**文件：**
- 修改：`Sources/CodexMonitor/Domain/MonitorModels.swift`

**接口：**
- 产出：`ProjectAnalyticsRange`、`ProjectAnalyticsRow`、`ProjectAnalyticsPeriodSnapshot`、`ProjectAnalyticsSnapshot`；
- 产出：`MonitorSnapshot.projectAnalytics`，默认值为 `.empty`。

- [ ] **步骤 1：增加三个固定范围**

```swift
enum ProjectAnalyticsRange: CaseIterable, Hashable, Sendable {
    case sevenDays
    case thirtyDays
    case all
}
```

- [ ] **步骤 2：增加页面只读快照模型**

```swift
struct ProjectAnalyticsRow: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let tokens: Int
    let sessions: Int
    let activeDays: Int
    let share: Double
}

struct ProjectAnalyticsPeriodSnapshot: Equatable, Sendable {
    let activeProjects: Int
    let totalTokens: Int
    let totalSessions: Int
    let rows: [ProjectAnalyticsRow]
}

struct ProjectAnalyticsSnapshot: Equatable, Sendable {
    let periods: [ProjectAnalyticsRange: ProjectAnalyticsPeriodSnapshot]
    let generatedAt: Date?
}
```

- [ ] **步骤 3：将项目分析快照加入总快照**

```swift
struct MonitorSnapshot: Equatable, Sendable {
    var projectAnalytics: ProjectAnalyticsSnapshot = .empty
}
```

### 任务 2：后台增量项目索引

**文件：**
- 新建：`Sources/CodexMonitor/Data/ProjectAnalyticsIndex.swift`

**接口：**
- 消费：`[SessionSummary]`；
- 产出：`func update(sessions:now:calendar:) -> ProjectAnalyticsSnapshot`。

- [ ] **步骤 1：建立 actor 与轻量索引记录**

```swift
actor ProjectAnalyticsIndex {
    private struct IndexedSession: Equatable, Sendable {
        let id: String
        let projectName: String
        let day: Date
        let tokens: Int
        let updatedAt: Date
    }

    private var sessionsByID: [String: IndexedSession] = [:]
    private var buckets: [String: [Date: [String: Int]]] = [:]
}
```

- [ ] **步骤 2：按最新 `updatedAt` 去重并差异更新桶**

```swift
func update(
    sessions: [SessionSummary],
    now: Date = .now,
    calendar: Calendar = .current
) -> ProjectAnalyticsSnapshot
```

构建当前会话字典；移除消失或变化的旧记录；加入新增或变化记录。空项目名称被丢弃，负 Token 钳制为零。

- [ ] **步骤 3：生成三个范围结果**

对每个项目统计 Token、唯一会话数和活跃日期集合，按 Token、会话数和名称稳定排序。超过六个项目时输出前五名和一条「其他项目」。占比相对所选范围项目 Token 总量计算。

### 任务 3：后台刷新接入

**文件：**
- 修改：`Sources/CodexMonitor/Data/UsageAggregator.swift`
- 修改：`Sources/CodexMonitor/Data/MonitorStore.swift`

**接口：**
- 消费：`ProjectAnalyticsSnapshot`；
- 产出：包含项目分析数据的 `MonitorSnapshot`。

- [ ] **步骤 1：让总聚合器接收项目快照**

```swift
static func makeSnapshot(
    sessions: [SessionSummary],
    projectAnalytics: ProjectAnalyticsSnapshot = .empty,
    now: Date = .now,
    calendar: Calendar = .current
) -> MonitorSnapshot
```

- [ ] **步骤 2：在 `MonitorStore` 持有索引 actor**

```swift
private let projectAnalyticsIndex = ProjectAnalyticsIndex()
```

- [ ] **步骤 3：扫描完成后等待后台统计快照**

```swift
let sessions = try await scanner(root)
let projectAnalytics = await projectAnalyticsIndex.update(sessions: sessions)
snapshot = UsageAggregator.makeSnapshot(
    sessions: sessions,
    projectAnalytics: projectAnalytics
)
```

### 任务 4：第 3 页 SwiftUI 界面

**文件：**
- 新建：`Sources/CodexMonitor/Notch/ProjectAnalyticsPage.swift`

**接口：**
- 消费：`ProjectAnalyticsSnapshot` 和 `reduceMotion`；
- 本地状态：`selectedRange`、`hoveredProjectID`。

- [ ] **步骤 1：实现标题与范围选择器**

```swift
struct ProjectAnalyticsPage: View {
    let analytics: ProjectAnalyticsSnapshot
    let reduceMotion: Bool
    @State private var selectedRange: ProjectAnalyticsRange = .sevenDays
    @State private var hoveredProjectID: String?
}
```

范围按钮为 `7 天`、`30 天`、`全部`，切换时只读取 `analytics.periods[selectedRange]`。

- [ ] **步骤 2：实现三项摘要与排名列表**

摘要展示活跃项目、项目 Token 和项目会话；排名行展示项目名称、相对第一名的紫色进度条、Token 和真实占比，最多六行。

- [ ] **步骤 3：实现悬停详情与空状态**

悬停或键盘聚焦显示：

```text
项目名称 · N 次会话 · N 个活跃日 · 平均 N Token/会话
```

无数据时显示「这个时间范围还没有项目数据」。减少动态效果开启时禁用进度条补间动画。

### 任务 5：五页导航和 GitHub 加载顺序

**文件：**
- 修改：`Sources/CodexMonitor/Notch/NotchLayout.swift`
- 修改：`Sources/CodexMonitor/Notch/NotchDashboardView.swift`

**接口：**
- 产出：`NotchLayout.pageCount == 5`；
- 产出：页面索引 `0...4` 的固定路由。

- [ ] **步骤 1：分页数量改为五页**

```swift
static let pageCount = 5
```

- [ ] **步骤 2：按确认顺序路由页面**

```swift
switch page {
case 0: WeeklyQuotaPage(snapshot: snapshot)
case 1: DailyActivityPage(snapshot: snapshot)
case 2: ProjectAnalyticsPage(analytics: snapshot.projectAnalytics, reduceMotion: reduceMotion)
case 3: StatisticsPage(snapshot: snapshot)
default: GitHubActivityPage(store: githubStore)
}
```

- [ ] **步骤 3：仅在第 5 页延迟加载 GitHub**

```swift
guard newPage == 4 else { return }
```

### 任务 6：版本更新、打包与提交

**文件：**
- 修改：`Resources/Info.plist`
- 生成：`dist/Codex Monitor.app`

- [ ] **步骤 1：更新版本**

将短版本从 `0.1.5` 更新为 `0.1.6`，构建号从 `6` 更新为 `7`。

- [ ] **步骤 2：执行 Release 打包**

运行：`bash scripts/package-app.sh`

预期：Swift Release 编译成功、应用完成临时签名，并输出 `dist/Codex Monitor.app`。

- [ ] **步骤 3：确认产物和版本信息**

仅检查 `.app` 路径、可执行文件、签名和 `Info.plist` 版本；不运行单元测试或界面测试。

- [ ] **步骤 4：提交中文变更**

```bash
git add Sources/CodexMonitor Resources/Info.plist docs/superpowers
git commit -m "功能：增加项目分析页面"
```
