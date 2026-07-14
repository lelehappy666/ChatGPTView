# 按会话发送完成通知实施计划

> **供执行人员使用：** 必须使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans`，按任务逐项实施。步骤使用复选框跟踪。

**目标：** 将完成通知从项目聚合状态切换为 Codex 会话状态，哪个会话完成就通知哪个会话，并以项目名称作为通知标题。

**架构：** 扫描器从 `session_meta` 提取会话 ID 与代理昵称，聚合器在项目汇总之外生成独立的 `SessionActivity` 列表。会话完成检测器只按会话 ID 和完成时间去重，应用委托将检测结果交给系统通知器。

**技术栈：** Swift 6.2、Foundation、Combine、UserNotifications、XCTest、macOS 14+

## 全局约束

- 所有文档使用中文。
- 所有 Git 提交信息使用中文。
- 通知标题必须是项目名称。
- 通知正文必须能区分具体会话。
- 首个真实快照不得通知历史完成会话。
- 同一会话同一完成时间只通知一次。

---

### 任务一：解析并输出会话活动

**文件：**
- 修改：`Sources/CodexMonitor/Data/CodexJSONL.swift`
- 修改：`Sources/CodexMonitor/Data/SessionScanner.swift`
- 修改：`Sources/CodexMonitor/Domain/MonitorModels.swift`
- 修改：`Sources/CodexMonitor/Data/UsageAggregator.swift`
- 修改：`Tests/CodexMonitorTests/JSONLDecoderTests.swift`
- 修改：`Tests/CodexMonitorTests/UsageAggregatorTests.swift`

**接口：**
- 输出：`SessionSummary.sessionID: String`
- 输出：`SessionSummary.agentNickname: String?`
- 输出：`SessionActivity(id:projectName:displayName:state:updatedAt:)`
- 输出：`MonitorSnapshot.sessions: [SessionActivity]`

- [ ] **步骤一：添加扫描器失败测试**

创建包含 `id`、`agent_nickname`、`cwd` 和任务状态的临时 JSONL，断言解析结果保留稳定会话 ID 与昵称；普通会话断言展示名回退为本地时间格式 `HH:mm 会话`。

- [ ] **步骤二：添加聚合器失败测试**

输入同项目的一个运行会话和一个完成会话，断言 `snapshot.sessions` 同时保留两条独立记录，不被项目聚合折叠。

- [ ] **步骤三：运行测试并确认失败**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/tmp/codex-monitor-clang-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/tmp/codex-monitor-swift-cache \
  swift test --disable-sandbox --filter 'JSONLDecoderTests|UsageAggregatorTests'
```

预期：会话身份字段和 `snapshot.sessions` 尚不存在，测试编译失败。

- [ ] **步骤四：实现最小会话模型与解析**

`CodexEnvelope.Payload` 增加 `id`、`sessionID` 和 `agentNickname` 解码字段。`SessionScanner` 优先使用元数据 ID，缺失时使用 JSONL 文件名作为稳定回退；展示名优先使用昵称，否则使用会话开始时间。

- [ ] **步骤五：生成独立会话活动列表**

`UsageAggregator` 将所有具有项目名称的 `SessionSummary` 映射为 `SessionActivity`，项目汇总逻辑保持用于菜单栏，不再承担通知输入。

- [ ] **步骤六：运行专项测试并确认通过**

运行步骤三的命令，预期相关测试零失败。

---

### 任务二：按会话检测完成事件

**文件：**
- 修改：`Sources/CodexMonitor/Notifications/ProjectCompletionDetector.swift`
- 修改：`Tests/CodexMonitorTests/ProjectCompletionDetectorTests.swift`

**接口：**
- 输出：`SessionCompletionDetector.completedSessions(in:) -> [SessionActivity]`

- [ ] **步骤一：添加会话级失败测试**

覆盖同项目一条运行会话和一条完成会话、两个不同完成会话、重复完成时间、同一会话再次完成、首次历史快照五种行为。

- [ ] **步骤二：运行测试并确认失败**

运行 `swift test --disable-sandbox --filter ProjectCompletionDetectorTests`，预期旧检测器因按项目名称去重而失败。

- [ ] **步骤三：实现会话完成时间去重**

检测器首帧记录所有已完成会话的完成时间；后续只返回会话 ID 首次出现或完成时间更晚的 `.completed` 记录。运行和失败记录不改变已通知完成时间。

- [ ] **步骤四：运行专项测试并确认通过**

运行步骤二的命令，预期全部通过。

---

### 任务三：发送以项目名称为标题的系统通知

**文件：**
- 修改：`Sources/CodexMonitor/Notifications/ProjectCompletionNotifier.swift`
- 修改：`Sources/CodexMonitor/App/AppDelegate.swift`
- 修改：`Tests/CodexMonitorTests/ProjectCompletionNotifierTests.swift`

**接口：**
- 输出：`CompletionNotificationMessage.message(projectName:sessionName:)`
- 输出：`ProjectCompletionNotifier.notify(projectName:sessionName:)`

- [ ] **步骤一：添加通知文案失败测试**

断言项目 `Replaypoker(ios)` 与会话 `Carson` 产生标题 `Replaypoker(ios)`、正文 `Carson 会话已完成`；时间回退名产生 `14:36 会话已完成`。

- [ ] **步骤二：运行测试并确认失败**

运行 `swift test --disable-sandbox --filter ProjectCompletionNotifierTests`，预期旧固定标题失败。

- [ ] **步骤三：修改通知器与应用订阅**

通知器接收项目名和会话展示名；`AppDelegate` 将 `snapshot.sessions` 交给会话检测器，并逐条发送通知。

- [ ] **步骤四：运行专项测试并确认通过**

运行步骤二命令，预期全部通过。

---

### 任务四：完整验证、打包与重启

- [ ] **步骤一：运行完整测试**

使用相同 Xcode 环境变量运行 `swift test --disable-sandbox`，预期零失败。

- [ ] **步骤二：重新打包并验证签名**

```bash
bash scripts/package-app.sh
codesign --verify --deep --strict --verbose=2 'dist/Codex Monitor.app'
```

- [ ] **步骤三：提交实现**

```bash
git add Sources Tests docs/superpowers/plans/2026-07-14-session-completion-notification.md
git commit -m '修复：按会话发送项目完成通知'
```

- [ ] **步骤四：重启开机自启动实例**

```bash
launchctl kickstart -k gui/501/com.dafeng.codexmonitor.loginitem
```

验证 LaunchAgent 为 `running` 且只有一个 `CodexMonitor` 进程。
