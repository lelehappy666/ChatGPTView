# Windows 11 ChatGPT 监控器设计规格

## 目标

在保留 macOS 版本核心信息结构的基础上，为 Windows 11 提供原生桌面监控器。应用常驻系统托盘，在屏幕顶部中央显示紧凑胶囊；点击后展开周额度、每日活动和统计总览三页数据。

## 界面

- 顶部紧凑状态栏固定显示 `ChatGPT`、`Week 30%` 和当前项目状态，所有内容横向排列。
- 展开窗口尺寸约为 430×300 像素，使用 Windows 11 深色圆角和半透明视觉。
- 第一页显示主 Codex 周额度、已用比例和重置时间。
- 第二页显示最近 60 天活动格子；鼠标悬停立即显示日期、Token 和会话数。
- 第三页使用 2×2 卡片显示累计 Token、峰值 Token、最长任务时长、当前/最长连续天数，禁止文字裁切。
- 系统托盘提供打开监控、立即刷新、开机启动和退出。

## 数据来源

- 默认读取 `%USERPROFILE%\.codex\sessions` 中的 JSONL 会话文件。
- 周额度只优先采用 `rate_limits.limit_id == "codex"` 且窗口为 10080 分钟的数据；没有主额度时才回退到其他周窗口。
- 项目名称取会话 `cwd` 的最后一级目录，不把用户主目录名称当成项目。
- 会话状态由最后一个 `task_started`、`task_complete` 或 `turn_aborted` 决定。
- 通知只允许同一个会话发生已观察到的 `running → completed` 转换时触发，标题使用项目名称，正文包含会话名称。

## Windows 技术方案

- 使用 .NET 8 和 Windows Forms，不引入第三方 NuGet 依赖。
- 使用无边框置顶窗口绘制顶部胶囊和展开面板。
- 使用 `NotifyIcon` 提供系统托盘菜单和带系统音效的完成通知。
- 使用 `FileSystemWatcher` 监听会话目录，并通过防抖刷新聚合数据。
- 使用 Windows 注册表 `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` 控制开机启动。

## 打包

- 根目录提供 `build-win11.bat`。
- Windows 11 安装 .NET 8 SDK 后，双击 BAT 生成单文件、自包含的 x64 可执行程序。
- 输出路径固定为 `dist-win11\ChatGPT.exe`。

## macOS 同步修复

- 大会话文件不能仅依赖固定 1 MB 尾部判断状态；需要从文件末尾反向扫描，直到找到最后一个生命周期事件。
- 完成通知必须以前一次已观察状态为 `running` 作为前置条件。

## 验收标准

- Windows 顶部紧凑栏中 `ChatGPT` 与 `Week xx%` 横向显示。
- 三页数据没有遮挡，统计总览完整显示“当前/最长连续”。
- Windows BAT 能在 Windows 11 的 .NET 8 SDK 环境生成 `dist-win11\ChatGPT.exe`。
- macOS 不再对仍处于 `task_started` 状态的会话发送完成通知。

