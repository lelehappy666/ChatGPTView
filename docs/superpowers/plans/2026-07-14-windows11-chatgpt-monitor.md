# Windows 11 ChatGPT 监控器实施计划

> **执行说明：** 在当前会话中按任务顺序实施。用户明确要求本次不新增或运行测试，完成后由用户在 Windows 11 真机测试。

**目标：** 开发 Windows 11 原生 ChatGPT 监控器、提供一键 BAT 打包命令，并修复 macOS 会话仍运行却提前通知完成的问题。

**架构：** Windows 端采用 .NET 8 Windows Forms，由数据扫描、聚合、完成检测、顶部窗口、托盘控制五个独立单元组成。macOS 端在现有扫描器中加入反向生命周期事件读取，并收紧完成通知状态机。

**技术栈：** Swift 6、.NET 8、C#、Windows Forms、System.Text.Json、FileSystemWatcher、NotifyIcon。

## 全局约束

- 所有文档和 Git 提交信息使用中文。
- Windows 应用名称显示为 `ChatGPT`。
- 顶部 `Week` 和百分比必须横向排列。
- 不新增或运行自动化测试。
- Windows 最终由 `build-win11.bat` 在 Windows 11 上打包。

---

### 任务一：修复 macOS 会话完成误报

**文件：**
- 修改：`Sources/CodexMonitor/Data/SessionScanner.swift`
- 修改：`Sources/CodexMonitor/Notifications/ProjectCompletionDetector.swift`

**接口：**
- `SessionScanner.latestLifecycleEvent(in:)` 从文件末尾反向读取最后一个生命周期事件。
- `SessionCompletionDetector.completedSessions(in:)` 仅返回上一次状态为运行中、当前状态为完成的会话。

- [ ] 在 `SessionScanner` 添加反向分块读取，解析最后一个 `task_started`、`task_complete` 或 `turn_aborted`。
- [ ] 使用反向结果覆盖头尾采样得到的陈旧状态和时间。
- [ ] 将完成检测器改为保存所有已观察会话状态，只接受 `running → completed`。
- [ ] 编译并重新打包 macOS 应用。

### 任务二：建立 Windows 项目与数据模型

**文件：**
- 创建：`Windows/ChatGPTMonitor/ChatGPTMonitor.csproj`
- 创建：`Windows/ChatGPTMonitor/Program.cs`
- 创建：`Windows/ChatGPTMonitor/Models.cs`
- 创建：`Windows/ChatGPTMonitor/CodexDataService.cs`

**接口：**
- `CodexDataService.RefreshAsync()` 返回 `MonitorSnapshot`。
- `CodexDataService.SnapshotChanged` 发布最新聚合数据。
- `CodexDataService.SessionCompleted` 发布准确的完成会话。

- [ ] 创建 .NET 8 Windows Forms 项目，配置 WinExe、x64、单文件发布兼容项。
- [ ] 定义周额度、每日活动、统计、项目和会话模型。
- [ ] 流式解析 JSONL，读取项目、Token、主 Codex 周额度和生命周期事件。
- [ ] 聚合 60 天活动、连续天数、峰值和最长任务时间。
- [ ] 使用 `FileSystemWatcher` 与防抖计时器刷新数据。
- [ ] 完成检测只在已观察的同会话 `running → completed` 时发出事件。

### 任务三：开发顶部动态岛界面

**文件：**
- 创建：`Windows/ChatGPTMonitor/Theme.cs`
- 创建：`Windows/ChatGPTMonitor/TopIslandForm.cs`
- 创建：`Windows/ChatGPTMonitor/ActivityGridControl.cs`

**接口：**
- `TopIslandForm.UpdateSnapshot(MonitorSnapshot snapshot)` 更新三页显示。
- `TopIslandForm.ToggleExpanded()` 切换 286×48 与 430×300。
- `ActivityGridControl.Days` 接收最近 60 天活动。

- [ ] 创建无边框、置顶、不进入任务栏的顶部中央窗口。
- [ ] 绘制横向 `ChatGPT`、`Week xx%` 和项目状态。
- [ ] 实现周额度、每日活动和统计总览三个页面按钮。
- [ ] 实现活动格子即时悬停提示。
- [ ] 使用 2×2 统计布局，确保所有文字完整可见。

### 任务四：系统托盘、通知和开机启动

**文件：**
- 创建：`Windows/ChatGPTMonitor/TrayController.cs`
- 创建：`Windows/ChatGPTMonitor/StartupManager.cs`

**接口：**
- `TrayController.ShowCompletion(SessionActivity session)` 显示标题为项目名称的系统通知。
- `StartupManager.IsEnabled` 和 `StartupManager.SetEnabled(bool)` 管理当前用户开机启动。

- [ ] 创建托盘图标和打开、刷新、开机启动、退出菜单。
- [ ] 完成会话时使用项目名作为通知标题并播放系统通知音。
- [ ] 注册和取消 `HKCU` 当前用户启动项。
- [ ] 应用退出时释放监听器、托盘图标和窗口资源。

### 任务五：Windows 一键打包与中文说明

**文件：**
- 创建：`build-win11.bat`
- 创建：`Windows/README.md`

- [ ] BAT 检查 `dotnet` 和 .NET 8 SDK，缺失时显示中文提示。
- [ ] 调用 `dotnet publish` 生成 win-x64、自包含、单文件 WinExe。
- [ ] 将最终文件复制为 `dist-win11\ChatGPT.exe`。
- [ ] 中文 README 说明打包、运行、数据目录与通知权限。
- [ ] 检查文件结构和 BAT 命令参数，不运行自动化测试。

