# 仅顶层会话完成提醒实施计划

> **给自动化执行者：** 必须使用 `superpowers:executing-plans`，按任务逐项执行并在每个任务中遵循测试驱动开发。

**目标：** macOS 与 Windows 只对用户可见的顶层 Codex 会话发送完成通知，内部子代理与 guardian 完成时不弹窗、不播放音效。

**架构：** JSONL 解析层统一依据 `parent_thread_id` 与 `source` 计算 `isTopLevel`，会话汇总和活动模型只传递这一语义字段。用量聚合继续处理全部会话，完成候选检测、等待中取消和最终确认只允许 `isTopLevel == true` 的会话通过。

**技术栈：** C# / .NET 8 / Windows Forms、Swift 6.2 / AppKit / XCTest、Codex JSONL 会话日志。

## 全局约束

- `parent_thread_id` 非空、`source` 包含 `subagent` 键、或 `source` 任意层级出现 `"other": "guardian"` 时，必须判定为内部会话。
- 层级字段缺失时兼容为顶层会话。
- 内部会话仍参与额度、Token、每日活动与统计聚合。
- 完成键继续使用 `session_id::turn_id`；缺少 `turn_id` 时不通知。
- 顶层候选继续等待 3 秒、主动刷新、再等待 1 秒，并受 15 秒新鲜度限制。
- macOS 与 Windows 使用同一层级判断和通知规则。
- 所有文档和 Git 提交信息使用中文。
- 直接在当前 `main` 分支实施，不创建工作树或功能分支。

---

### 任务 1：Windows 解析并传递顶层会话身份

**文件：**
- 修改：`Windows/ChatGPTMonitor/Models.cs`
- 修改：`Windows/ChatGPTMonitor/CodexDataService.cs`
- 修改：`Windows/ChatGPTMonitor.LayoutChecks/Program.cs`

**接口：**
- `SessionSummary` 末尾新增 `bool IsTopLevel = true`。
- `SessionActivity` 末尾新增 `bool IsTopLevel = true`。
- `CodexDataService.IsTopLevelSession(JsonElement payload)` 返回元数据是否属于顶层会话。
- `CodexDataService.BuildSnapshot(IReadOnlyList<SessionSummary>)` 改为 `internal static`，供契约检查验证内部会话仍进入统计。

- [ ] **步骤 1：编写 Windows 元数据失败契约**

在 `Program.cs` 创建根会话、子代理和 guardian 三个临时 JSONL，断言：

```csharp
Check(rootSummary?.IsTopLevel == true, "无父会话的 vscode 会话应为顶层");
Check(childSummary?.IsTopLevel == false, "thread_spawn 子代理不能成为通知会话");
Check(guardianSummary?.IsTopLevel == false, "guardian 不能成为通知会话");
```

子代理元数据采用真实结构：

```json
{"type":"session_meta","payload":{"type":"session_meta","id":"child","cwd":"C:\\Projects\\Replaypoker","parent_thread_id":"root","source":{"subagent":{"thread_spawn":{"parent_thread_id":"root"}}}}}
```

guardian 元数据采用：

```json
{"type":"session_meta","payload":{"type":"session_meta","id":"guardian","cwd":"C:\\Projects\\Replaypoker","parent_thread_id":"root","source":{"subagent":{"other":"guardian"}}}}
```

- [ ] **步骤 2：运行契约并确认失败**

运行：

```text
dotnet run --project Windows/ChatGPTMonitor.LayoutChecks/ChatGPTMonitor.LayoutChecks.csproj --configuration Release
```

预期：因模型没有 `IsTopLevel` 或解析结果仍为顶层而失败。

- [ ] **步骤 3：实现递归来源判断与模型传递**

在 `CodexDataService` 中加入递归判断，核心逻辑固定为：

```csharp
private static bool IsInternalSource(JsonElement value)
{
    if (value.ValueKind == JsonValueKind.Object)
    {
        foreach (var property in value.EnumerateObject())
        {
            if (property.NameEquals("subagent")) return true;
            if (property.NameEquals("other") &&
                property.Value.ValueKind == JsonValueKind.String &&
                string.Equals(property.Value.GetString(), "guardian", StringComparison.OrdinalIgnoreCase))
                return true;
            if (IsInternalSource(property.Value)) return true;
        }
    }
    if (value.ValueKind == JsonValueKind.Array)
        return value.EnumerateArray().Any(IsInternalSource);
    return false;
}
```

`session_meta` 解析时检查去除空白后的 `parent_thread_id`，再检查 `source`；结果写入 `SessionSummary.IsTopLevel`，构建 `SessionActivity` 时原样传递。

- [ ] **步骤 4：验证内部会话仍参与统计**

在契约检查中将根会话和子代理汇总交给 `BuildSnapshot`，断言：

```csharp
Check(snapshot.LifetimeTokens == rootTokens + childTokens, "内部会话 Token 不得从统计中丢失");
Check(snapshot.Sessions.Single(item => item.Id == "child").IsTopLevel == false, "内部身份必须传到活动模型");
```

- [ ] **步骤 5：重跑契约并提交**

运行同一步骤 2，预期输出 `全部布局与通知契约检查通过`。

```bash
git add Windows/ChatGPTMonitor/Models.cs Windows/ChatGPTMonitor/CodexDataService.cs Windows/ChatGPTMonitor.LayoutChecks/Program.cs
git commit -m "修复：识别 Windows 顶层与内部会话"
```

### 任务 2：Windows 完成检测只允许顶层会话

**文件：**
- 修改：`Windows/ChatGPTMonitor/SessionCompletionDetector.cs`
- 修改：`Windows/ChatGPTMonitor/CompletionNotificationCoordinator.cs`
- 修改：`Windows/ChatGPTMonitor.LayoutChecks/Program.cs`

**接口：**
- `SessionCompletionDetector.Observe(...)` 在建立基线和发现候选前排除 `IsTopLevel == false`。
- `CompletionConfirmation.Matches(...)` 要求候选和最终快照都为顶层。
- `CompletionNotificationCoordinator.CancelInvalidPending(...)` 在最新会话不是顶层时立即取消等待任务。

- [ ] **步骤 1：编写 Replaypoker 误报失败契约**

测试辅助函数增加 `bool isTopLevel = true`，建立“根会话运行、Epicurus 子代理运行”的基线，然后仅完成子代理：

```csharp
var hierarchyDetector = new SessionCompletionDetector();
Check(hierarchyDetector.Observe(new[]
{
    Session("root", "Replaypoker(ios)", SessionState.Running, 100, "root-turn", true),
    Session("Epicurus", "Replaypoker(ios)", SessionState.Running, 100, "child-turn", false)
}).Count == 0, "首次层级快照只应建立基线");
Check(hierarchyDetector.Observe(new[]
{
    Session("root", "Replaypoker(ios)", SessionState.Running, 101, "root-turn", true),
    Session("Epicurus", "Replaypoker(ios)", SessionState.Completed, 101, "child-turn", false)
}).Count == 0, "子代理完成不能触发项目通知");
```

随后将根会话改为完成，断言只返回 `root`。另外断言 `CompletionConfirmation.Matches` 对非顶层候选和非顶层最终快照均返回 `false`。

- [ ] **步骤 2：运行契约并确认子代理仍被识别为候选**

运行 Windows 契约检查，预期“子代理完成不能触发项目通知”失败。

- [ ] **步骤 3：实现最小顶层过滤与取消规则**

候选过滤增加：

```csharp
.Where(item =>
    item.IsTopLevel &&
    item.State == SessionState.Completed &&
    !string.IsNullOrWhiteSpace(item.TurnId))
```

最终确认增加 `candidate.IsTopLevel && latest.IsTopLevel`；等待中取消条件增加 `!latest.IsTopLevel`。不修改刷新时序、完成键和新鲜度限制。

- [ ] **步骤 4：运行 Windows 契约与 Release 构建**

```text
dotnet run --project Windows/ChatGPTMonitor.LayoutChecks/ChatGPTMonitor.LayoutChecks.csproj --configuration Release
dotnet build Windows/ChatGPTMonitor/ChatGPTMonitor.csproj --configuration Release
```

预期：两条命令退出码均为 0。

- [ ] **步骤 5：提交**

```bash
git add Windows/ChatGPTMonitor/SessionCompletionDetector.cs Windows/ChatGPTMonitor/CompletionNotificationCoordinator.cs Windows/ChatGPTMonitor.LayoutChecks/Program.cs
git commit -m "修复：Windows 仅提醒顶层会话完成"
```

### 任务 3：macOS 解析并传递顶层会话身份

**文件：**
- 修改：`Sources/CodexMonitor/Data/CodexJSONL.swift`
- 修改：`Sources/CodexMonitor/Data/SessionScanner.swift`
- 修改：`Sources/CodexMonitor/Domain/MonitorModels.swift`
- 修改：`Sources/CodexMonitor/Data/UsageAggregator.swift`
- 修改：`Tests/CodexMonitorTests/JSONLDecoderTests.swift`
- 修改：`Tests/CodexMonitorTests/UsageAggregatorTests.swift`

**接口：**
- `CodexEnvelope.Payload` 新增 `parentThreadID` 与 `source`。
- `CodexSessionSource.isInternal` 递归识别 `subagent` 和 guardian。
- `SessionSummary` 与 `SessionActivity` 新增 `isTopLevel`，默认值为 `true`，保持旧测试与旧日志兼容。
- `UsageAggregator` 把 `SessionSummary.isTopLevel` 原样复制到 `SessionActivity`，但不据此过滤用量。

- [ ] **步骤 1：编写 macOS 元数据失败测试**

在 `JSONLDecoderTests` 添加真实根会话、`thread_spawn` 子代理、guardian 和缺失层级字段四组 JSONL，分别断言：

```swift
XCTAssertTrue(try XCTUnwrap(SessionScanner.parseFile(rootURL)).isTopLevel)
XCTAssertFalse(try XCTUnwrap(SessionScanner.parseFile(childURL)).isTopLevel)
XCTAssertFalse(try XCTUnwrap(SessionScanner.parseFile(guardianURL)).isTopLevel)
XCTAssertTrue(try XCTUnwrap(SessionScanner.parseFile(legacyURL)).isTopLevel)
```

- [ ] **步骤 2：运行定向测试并确认失败**

运行：`swift test --filter JSONLDecoderTests`

预期：因 `SessionSummary` 没有 `isTopLevel` 而编译失败。

- [ ] **步骤 3：实现来源解码和层级计算**

新增递归 JSON 值解码，仅保留通知层级所需语义：

```swift
struct CodexSessionSource: Decodable {
    let isInternal: Bool

    init(from decoder: Decoder) throws {
        isInternal = try SourceValue(from: decoder).containsInternalMarker
    }
}
```

`SourceValue.containsInternalMarker` 对对象键 `subagent` 直接返回真，对键 `other` 且字符串值为 `guardian` 返回真，并递归检查对象与数组。`SessionScanner` 使用：

```swift
let hasParent = !(payload.parentThreadID ?? "")
    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
isTopLevel = !hasParent && !(payload.source?.isInternal ?? false)
```

- [ ] **步骤 4：编写并通过用量保留测试**

在 `UsageAggregatorTests` 构造一个顶层与一个内部 `SessionSummary`，断言 `lifetimeTokens` 是两者之和、当天会话数为 2，并断言内部 `SessionActivity.isTopLevel == false`。

运行：`swift test --filter 'JSONLDecoderTests|UsageAggregatorTests'`

预期：所有定向测试通过。

- [ ] **步骤 5：提交**

```bash
git add Sources/CodexMonitor/Data Sources/CodexMonitor/Domain/MonitorModels.swift Tests/CodexMonitorTests/JSONLDecoderTests.swift Tests/CodexMonitorTests/UsageAggregatorTests.swift
git commit -m "修复：识别 macOS 顶层与内部会话"
```

### 任务 4：macOS 完成通知只允许顶层会话

**文件：**
- 修改：`Sources/CodexMonitor/Notifications/ProjectCompletionDetector.swift`
- 修改：`Sources/CodexMonitor/App/AppDelegate.swift`
- 修改：`Tests/CodexMonitorTests/ProjectCompletionDetectorTests.swift`

**接口：**
- `SessionCompletionDetector.completedSessions(in:)` 排除非顶层会话。
- `CompletionConfirmation.matches(...)` 要求候选和最终会话均为顶层。
- `CompletionPendingPolicy.keysToCancel(...)` 在最新会话不是顶层时取消同会话候选。
- `AppDelegate.scheduleCompletionNotification(for:)` 用 `session.isTopLevel` 做入口防御。

- [ ] **步骤 1：编写 Replaypoker 误报失败测试**

给测试辅助函数增加 `isTopLevel: Bool = true`，覆盖：

```swift
func testChildCompletionDoesNotNotifyWhileReplaypokerRootRuns() {
    var detector = SessionCompletionDetector()
    let root = session("root", project: "Replaypoker(ios)", state: .running, at: 100)
    let child = session("Epicurus", project: "Replaypoker(ios)", state: .running, at: 100, isTopLevel: false)
    XCTAssertTrue(detector.completedSessions(in: [root, child]).isEmpty)
    XCTAssertTrue(detector.completedSessions(in: [
        root,
        session("Epicurus", project: "Replaypoker(ios)", state: .completed, at: 101, isTopLevel: false)
    ]).isEmpty)
}
```

再增加顶层完成仍通知、最终确认拒绝内部会话、等待策略取消内部身份三项测试。

- [ ] **步骤 2：运行定向测试并确认失败**

运行：`swift test --filter ProjectCompletionDetectorTests`

预期：子代理完成测试失败。

- [ ] **步骤 3：实现最小过滤、确认与入口防御**

候选守卫改为：

```swift
guard session.isTopLevel,
      session.state == .completed,
      let turnID = session.turnID else { return nil }
```

`CompletionConfirmation` 增加候选和最新会话均为顶层；`CompletionPendingPolicy` 把 `!latest.isTopLevel` 视为失效；`AppDelegate` 的调度入口增加 `guard session.isTopLevel`。

- [ ] **步骤 4：运行 macOS 全量测试**

运行：`swift test`

预期：全部 XCTest 通过且无失败。

- [ ] **步骤 5：提交**

```bash
git add Sources/CodexMonitor/Notifications/ProjectCompletionDetector.swift Sources/CodexMonitor/App/AppDelegate.swift Tests/CodexMonitorTests/ProjectCompletionDetectorTests.swift
git commit -m "修复：macOS 仅提醒顶层会话完成"
```

### 任务 5：说明、完整验证、打包与重启

**文件：**
- 修改：`Windows/README.md`
- 生成：`dist-win11/ChatGPT.exe`
- 生成：`dist/Codex Monitor.app`

**接口：**
- 交付产物路径保持不变。
- macOS 包继续使用临时签名，Windows 继续生成 `win-x64` 自包含单文件。

- [ ] **步骤 1：更新中文行为说明**

在 `Windows/README.md` 明确：完成通知只针对没有父会话的顶层会话；子代理与 guardian 不提醒但仍计入统计；最终仍执行 3 秒等待、刷新和 1 秒复核。

- [ ] **步骤 2：执行完整验证**

依次运行：

```text
dotnet run --project Windows/ChatGPTMonitor.LayoutChecks/ChatGPTMonitor.LayoutChecks.csproj --configuration Release
dotnet build Windows/ChatGPTMonitor/ChatGPTMonitor.csproj --configuration Release
swift test
git diff --check
```

预期：所有命令退出码为 0，Windows 输出 `全部布局与通知契约检查通过`，Swift 测试零失败。

- [ ] **步骤 3：发布 Windows 自包含 EXE**

运行：

```text
dotnet publish Windows/ChatGPTMonitor/ChatGPTMonitor.csproj --configuration Release --runtime win-x64 --self-contained true --output Windows/ChatGPTMonitor/bin/publish-win11 -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:DebugType=None -p:DebugSymbols=false
```

将生成的 `ChatGPT.exe` 覆盖到 `dist-win11/ChatGPT.exe`，并确认文件存在且大小大于 0。

- [ ] **步骤 4：打包、签名并验证 macOS 应用**

运行：

```text
bash scripts/package-app.sh
codesign --verify --deep --strict --verbose=2 "dist/Codex Monitor.app"
```

预期：脚本输出 `dist/Codex Monitor.app`，签名验证退出码为 0。

- [ ] **步骤 5：重启并核对真实运行路径**

停止旧 `CodexMonitor` 进程，启动 `dist/Codex Monitor.app`，再用进程列表确认只运行一个实例，二进制路径为：

```text
/Users/lele/Desktop/大丰数艺/Codex额度/dist/Codex Monitor.app/Contents/MacOS/CodexMonitor
```

- [ ] **步骤 6：提交说明与产物**

```bash
git add Windows/README.md dist-win11/ChatGPT.exe "dist/Codex Monitor.app"
git commit -m "发布：更新顶层会话完成提醒产物"
```
