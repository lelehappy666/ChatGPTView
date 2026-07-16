# Windows 项目分析页面实施计划

> **执行约束：** 在当前 `main` 分支内直接实施；用户明确要求不运行测试，完成后直接发布 Windows 单文件包。

**目标：** 为 Windows 11 顶部监控器新增第 3 页项目分析，并生成自包含 `ChatGPT.exe`。

**架构：** `ProjectAnalyticsBuilder` 从已解析会话摘要生成 7 天、30 天和全部快照；`IslandRenderer` 只绘制当前快照。`TopIslandForm` 负责四页导航、范围按钮和项目行悬停命中。

**技术栈：** .NET 8、Windows Forms、System.Drawing、单文件 self-contained win-x64 发布

## 全局约束

- 页面顺序为周额度、每日活动、项目分析、统计总览；
- Windows 不新增 GitHub 页面；
- 不增加第三方依赖；
- 不运行布局检查或测试；
- 文档与提交信息使用中文；
- 最终输出 `dist-win11/ChatGPT.exe`。

### 任务 1：项目分析模型与聚合器

**文件：**
- 修改：`Windows/ChatGPTMonitor/Models.cs`
- 新建：`Windows/ChatGPTMonitor/ProjectAnalyticsBuilder.cs`

增加 `ProjectAnalyticsRange`、`ProjectAnalyticsRow`、`ProjectAnalyticsPeriod` 和 `ProjectAnalyticsSnapshot`。聚合器按最新会话去重，生成三个范围结果，并处理前五名加「其他项目」。

### 任务 2：后台刷新接入

**文件：**
- 修改：`Windows/ChatGPTMonitor/CodexDataService.cs`

把扫描与 `BuildSnapshot` 放在同一个后台任务中，并将 `ProjectAnalyticsBuilder.Build(summaries)` 写入 `MonitorSnapshot`。

### 任务 3：四页布局和命中区域

**文件：**
- 修改：`Windows/ChatGPTMonitor/IslandLayout.cs`

将导航扩展为四项，新增三个时间按钮、三张摘要卡和六条项目行的 DPI 缩放矩形及命中方法。

### 任务 4：项目分析绘制

**文件：**
- 修改：`Windows/ChatGPTMonitor/IslandRenderer.cs`

新增 `ProjectAnalytics` 页面枚举和绘制分支，绘制范围按钮、摘要卡、排名条、空状态和悬停高亮。

### 任务 5：鼠标交互

**文件：**
- 修改：`Windows/ChatGPTMonitor/TopIslandForm.cs`

新增范围状态和项目行悬停状态；点击完整按钮矩形切换范围；悬停项目行时使用原生 ToolTip 显示项目明细。

### 任务 6：说明与打包

**文件：**
- 修改：`Windows/README.md`
- 修改：`Windows/ChatGPTMonitor.LayoutChecks/Program.cs`

同步四页说明和布局契约源码，但不运行检查。使用：

```bash
dotnet publish Windows/ChatGPTMonitor/ChatGPTMonitor.csproj \
  --configuration Release \
  --runtime win-x64 \
  --self-contained true \
  --output Windows/ChatGPTMonitor/bin/publish-win11 \
  -p:PublishSingleFile=true \
  -p:IncludeNativeLibrariesForSelfExtract=true \
  -p:DebugType=None \
  -p:DebugSymbols=false
```

将生成的 `ChatGPT.exe` 复制到 `dist-win11/ChatGPT.exe`，随后使用中文提交。
