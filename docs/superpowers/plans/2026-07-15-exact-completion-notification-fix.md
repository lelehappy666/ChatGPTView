# 跨平台精确会话完成通知实施计划

> **给自动化执行者：** 必须使用 `superpowers:executing-plans`，按任务逐项执行并在每个任务中遵循测试驱动开发。

**目标：** Windows 与 macOS 只在准确的 Codex 会话轮次真实完成、延迟复核后仍保持完成时发送一次通知。

**架构：** Windows 解析器补齐 `turn_id` 与会话标题，将完成候选检测、刷新合并循环和最终确认拆成可独立测试的组件；数据服务只负责连接文件监听、快照与通知协调。macOS 保留现有状态机，补齐非完成状态即时取消，并用契约测试锁定两端一致规则。

**技术栈：** C# / .NET 8 / Windows Forms、Swift 6.2 / AppKit / XCTest、JSONL 会话日志。

## 全局约束

- 完成键必须为 `session_id::turn_id`。
- 缺少 `turn_id` 的事件绝不触发通知。
- 首次快照只建立基线，不补发历史通知。
- 候选等待 3 秒、主动刷新、再等待 1 秒后复核。
- 最终状态、会话 ID、轮次 ID、完成时间必须一致，且完成事件不超过 15 秒。
- 同一会话开始新轮次或变为运行、失败时，旧候选立即取消。
- 所有文档和 Git 提交信息使用中文。

---

### 任务 1：Windows 解析真实会话与轮次身份

**文件：**
- 修改：`Windows/ChatGPTMonitor/Models.cs`
- 修改：`Windows/ChatGPTMonitor/CodexDataService.cs`
- 修改：`Windows/ChatGPTMonitor.LayoutChecks/ChatGPTMonitor.LayoutChecks.csproj`
- 修改：`Windows/ChatGPTMonitor.LayoutChecks/Program.cs`

**接口：**
- `SessionSummary` 新增 `string? TurnId`。
- `SessionActivity` 新增 `string? TurnId`。
- `CodexDataService.ParseSession(string file)` 改为 `internal static`，供无第三方依赖契约检查直接调用。

- [ ] **步骤 1：编写失败的 JSONL 解析契约**

在布局契约检查中创建临时 JSONL，写入 `session_meta`、`user_message`、`task_started`、`task_complete`，断言：

```csharp
Check(summary?.Id == "session-456", "会话 ID 解析错误");
Check(summary?.TurnId == "turn-123", "轮次 ID 解析错误");
Check(summary?.DisplayName == "修复牌桌结算状态", "根会话标题解析错误");
```

- [ ] **步骤 2：运行契约检查并确认因缺失 `TurnId` 而失败**

运行：`dotnet run --project Windows/ChatGPTMonitor.LayoutChecks/ChatGPTMonitor.LayoutChecks.csproj --configuration Release`

预期：编译失败或断言失败，明确指出当前模型/解析器不支持轮次身份。

- [ ] **步骤 3：最小实现轮次和标题解析**

生命周期事件始终更新最新 `turn_id`；第一条有效 `user_message` 取首个非空且不以 `<`、`# AGENTS` 开头的文本行，截取 24 个字符；显示名顺序为昵称、会话标题、`HH:mm 会话`。

- [ ] **步骤 4：重跑契约检查并确认通过**

运行同上，预期输出 `全部布局与通知契约检查通过`。

- [ ] **步骤 5：提交**

```bash
git add Windows/ChatGPTMonitor Windows/ChatGPTMonitor.LayoutChecks
git commit -m "修复：解析 Windows 会话轮次与真实标题"
```

### 任务 2：Windows 用完成键检测候选并可靠处理刷新

**文件：**
- 创建：`Windows/ChatGPTMonitor/SessionCompletionDetector.cs`
- 创建：`Windows/ChatGPTMonitor/CoalescingRefreshRunner.cs`
- 修改：`Windows/ChatGPTMonitor/CodexDataService.cs`
- 修改：`Windows/ChatGPTMonitor.LayoutChecks/ChatGPTMonitor.LayoutChecks.csproj`
- 修改：`Windows/ChatGPTMonitor.LayoutChecks/Program.cs`

**接口：**
- `SessionCompletionDetector.Observe(IReadOnlyList<SessionActivity>)` 返回此前未见的完成轮次。
- `CompletionConfirmation.Matches(candidate, latest, now, freshness)` 执行最终一致性判断。
- `CoalescingRefreshRunner.Request()` 合并请求，但保证运行期间到达的请求会触发下一次执行。

- [ ] **步骤 1：编写候选检测失败契约**

覆盖首次完成基线、快速完成、重复完成、缺失轮次、同项目多会话、新轮次拒绝旧候选：

```csharp
var detector = new SessionCompletionDetector();
Check(detector.Observe(new[] { Completed("a", "turn-1", 100) }).Count == 0, "首次快照不应通知");
Check(detector.Observe(new[] { Completed("a", "turn-2", 101) }).Single().TurnId == "turn-2", "快速完成轮次应被识别");
Check(!CompletionConfirmation.Matches(candidate, Running("a", "turn-3", 102), now, TimeSpan.FromSeconds(15)), "新轮次必须拒绝旧候选");
```

- [ ] **步骤 2：运行并确认旧检测器失败**

运行布局契约检查，预期快速完成、缺失轮次或确认规则断言失败。

- [ ] **步骤 3：实现完成键检测与确认器**

检测器首次调用把已有 `completed + turn_id` 写入基线；后续只返回新键。确认器要求 ID、轮次、状态、时间戳完全一致，并拒绝未来时间或超过 15 秒的候选。

- [ ] **步骤 4：编写刷新不丢失的失败契约**

让第一次刷新阻塞，在其执行中再次调用 `Request()`，释放后断言操作总次数为 2。

- [ ] **步骤 5：实现合并刷新循环并重跑检查**

使用原子 `requested/running` 标志；循环每次消费一次待刷新标志，释放运行权后再次检查竞态窗口。预期全部契约通过。

- [ ] **步骤 6：提交**

```bash
git add Windows/ChatGPTMonitor Windows/ChatGPTMonitor.LayoutChecks
git commit -m "修复：按轮次检测完成并防止刷新丢失"
```

### 任务 3：Windows 延迟复核后再发送通知

**文件：**
- 创建：`Windows/ChatGPTMonitor/CompletionNotificationCoordinator.cs`
- 修改：`Windows/ChatGPTMonitor/CodexDataService.cs`
- 修改：`Windows/ChatGPTMonitor.LayoutChecks/ChatGPTMonitor.LayoutChecks.csproj`
- 修改：`Windows/ChatGPTMonitor.LayoutChecks/Program.cs`

**接口：**
- `CompletionNotificationCoordinator.Observe(snapshot)` 安排或取消候选。
- 构造函数接收刷新回调、当前快照读取器、通知回调、等待时间和时钟，生产配置为 3 秒、1 秒、15 秒。
- `Dispose()` 取消全部等待任务。

- [ ] **步骤 1：编写协调器失败契约**

使用可控等待器验证：候选不会立即通知；刷新后仍是同一完成轮次才通知；相同会话出现新轮次、运行或失败时立即取消；同一完成键只通知一次。

- [ ] **步骤 2：运行并确认协调器尚不存在**

运行布局契约检查，预期编译失败。

- [ ] **步骤 3：实现最小协调器并接入数据服务**

`RefreshOnceAsync` 只发布快照和候选；通知协调器负责等待、调用零延迟刷新、复核和触发 `SessionCompleted`。数据服务销毁时先取消协调器，再停止刷新循环。

- [ ] **步骤 4：重跑 Windows 契约与 Release 构建**

运行：

```text
dotnet run --project Windows/ChatGPTMonitor.LayoutChecks/ChatGPTMonitor.LayoutChecks.csproj --configuration Release
dotnet build Windows/ChatGPTMonitor/ChatGPTMonitor.csproj --configuration Release
```

预期：均以退出码 0 完成。

- [ ] **步骤 5：提交**

```bash
git add Windows/ChatGPTMonitor Windows/ChatGPTMonitor.LayoutChecks
git commit -m "修复：完成通知延迟刷新复核"
```

### 任务 4：macOS 取消策略与跨平台回归检查

**文件：**
- 修改：`Sources/CodexMonitor/Notifications/ProjectCompletionDetector.swift`
- 修改：`Sources/CodexMonitor/App/AppDelegate.swift`
- 修改：`Tests/CodexMonitorTests/ProjectCompletionDetectorTests.swift`
- 修改：`Tests/CodexMonitorTests/JSONLDecoderTests.swift`

**接口：**
- `CompletionPendingPolicy.keysToCancel(pendingKeys:latest:)` 返回同会话已经失效的候选键。

- [ ] **步骤 1：编写 macOS 失败测试**

新增同轮次状态从完成变为运行/失败时取消、不同会话互不影响、未来时间和过期完成拒绝确认的 XCTest。

- [ ] **步骤 2：运行定向测试并确认取消策略测试失败**

运行：`swift test --filter ProjectCompletionDetectorTests`

预期：因缺少 `CompletionPendingPolicy` 或当前逻辑未即时取消而失败。

- [ ] **步骤 3：实现纯取消策略并接入 AppDelegate**

同会话候选满足“键不同”或“最新状态不是完成”任一条件即取消；其他会话候选保持不变。

- [ ] **步骤 4：运行全部 macOS 测试**

运行：`swift test`

预期：全部 XCTest 通过。

- [ ] **步骤 5：提交**

```bash
git add Sources/CodexMonitor Tests/CodexMonitorTests
git commit -m "修复：对齐 macOS 完成通知取消规则"
```

### 任务 5：文档、打包与真机产物

**文件：**
- 修改：`Windows/README.md`
- 生成：`dist-win11/ChatGPT.exe`
- 生成：`dist/Codex Monitor.app`

- [ ] **步骤 1：更新中文说明**

明确 Windows 刷新不丢失、完成通知使用精确轮次与 4 秒稳定复核，并说明缺少轮次身份不通知。

- [ ] **步骤 2：执行完整验证**

运行 Windows 契约检查、Windows Release 构建、`swift test`、`git diff --check`，逐项确认退出码 0。

- [ ] **步骤 3：打包 Windows 与 macOS**

在 macOS 上使用已安装的 .NET 交叉发布 `win-x64` 单文件到 `dist-win11/ChatGPT.exe`；运行 `scripts/package-app.sh` 生成并临时签名 macOS 应用。

- [ ] **步骤 4：重启 macOS 应用并核对进程路径**

停止旧进程后启动 `dist/Codex Monitor.app`，确认实际运行的二进制来自最新产物。

- [ ] **步骤 5：最终提交**

```bash
git add Windows/README.md dist-win11/ChatGPT.exe "dist/Codex Monitor.app"
git commit -m "发布：更新精确会话完成通知产物"
```
