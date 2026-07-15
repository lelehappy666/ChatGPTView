# 悬停展开、弹出刷新与透明窗口实施计划

> **执行说明：** 使用 `superpowers:executing-plans` 在当前会话逐项实施；所有步骤使用复选框跟踪。

**目标：** 让 Windows 顶部胶囊悬停展开、移开收起并移除矩形 DWM 底板，同时让 Windows 与 macOS 每次实际弹出时刷新一次额度数据。

**架构：** Windows 新增纯状态机管理悬停意图，WinForms 计时器只负责 80/180 毫秒调度，状态机决定展开、收起和单次刷新。Windows DWM 策略改为无系统背景；macOS 在现有 `show(on:)` 的真实显示入口触发刷新。

**技术栈：** C#、.NET 8、Windows Forms、DWM、Swift 6、AppKit、XCTest。

## 全局约束

- 所有文档和 Git 提交信息使用中文。
- Windows 进入等待 80 毫秒，离开等待 180 毫秒。
- 每次从收起进入展开只刷新一次。
- 保留启动、文件监听和手动刷新入口。
- 最终更新 `dist-win11\ChatGPT.exe` 与 `dist/Codex Monitor.app`。

---

### 任务一：Windows 悬停状态机

**文件：**
- 创建：`Windows/ChatGPTMonitor/HoverExpansionState.cs`
- 修改：`Windows/ChatGPTMonitor.LayoutChecks/ChatGPTMonitor.LayoutChecks.csproj`
- 修改：`Windows/ChatGPTMonitor.LayoutChecks/Program.cs`
- 修改：`Windows/ChatGPTMonitor/TopIslandForm.cs`
- 修改：`Windows/ChatGPTMonitor/Program.cs`

**接口：**
- `HoverExpansionState.PointerEntered()` 与 `PointerExited()` 记录指针状态。
- `OpenDelayElapsed()` 返回 `ExpandAndRefresh` 或 `None`。
- `CloseDelayElapsed()` 返回 `Collapse` 或 `None`。
- `ForceExpanded()` 供托盘使用，窗口已展开时返回 `None`。

- [ ] 先在布局检查程序中加入短暂经过、稳定悬停、移开、重新进入、重复移动和托盘主动展开断言。
- [ ] 运行检查，确认因状态机缺失而编译失败。
- [ ] 实现最小状态机并使检查通过。
- [ ] 在 `TopIslandForm` 中加入 80/180 毫秒计时器，移除标题点击切换，展开动作调用一次刷新回调。
- [ ] 修改 `Program.cs` 将 `_dataService.RequestRefresh` 传入窗口。
- [ ] 构建 Windows Release，提交中文 Git 记录。

### 任务二：Windows 四周透明

**文件：**
- 修改：`Windows/ChatGPTMonitor/WindowsBackdrop.cs`
- 修改：`Windows/ChatGPTMonitor.LayoutChecks/ChatGPTMonitor.LayoutChecks.csproj`
- 修改：`Windows/ChatGPTMonitor.LayoutChecks/Program.cs`

**接口：**
- `WindowsBackdrop.SystemBackdropTypeForIsland` 固定为 `DWMSBT_NONE` 的值 `1`。
- `WindowsBackdrop.CornerPreferenceForIsland` 固定为 `DWMWCP_DONOTROUND` 的值 `1`。

- [ ] 先加入 DWM 策略契约断言，并确认当前主窗口材质值 `2` 导致失败。
- [ ] 将系统背景类型改为无背景，并让 Region 独立负责圆角。
- [ ] 运行全部 Windows 契约检查和 Release 构建。
- [ ] 发布 win-x64 自包含 EXE 并覆盖 `dist-win11\ChatGPT.exe`。
- [ ] 提交中文 Git 记录。

### 任务三：macOS 弹出时刷新

**文件：**
- 修改：`Sources/CodexMonitor/Notch/NotchWindowController.swift`
- 修改：`Tests/CodexMonitorTests/AppIntegrationTests.swift`

**接口：**
- `NotchRefreshPolicy.shouldRequestRefresh(isPanelVisible:)` 只在隐藏窗口即将显示时返回 `true`。
- `show(on:)` 在显示动画开始前调用 `store.requestRefresh()`。

- [ ] 先添加隐藏状态刷新、已显示状态不重复刷新测试并确认失败。
- [ ] 实现刷新策略并在 `show(on:)` 接入刷新请求。
- [ ] 运行 macOS 全部测试并打包签名应用。
- [ ] 重启 macOS LaunchAgent。
- [ ] 提交中文 Git 记录并执行最终双端验证。
