# 菜单状态、活动提示与登录启动设计

状态：用户已要求直接优化并设置开机自启动。

## 菜单栏状态

- “进行中”使用 macOS 高饱和系统蓝 `#0A84FF`。
- 状态点从 6 px 增至 8 px，并保留清晰蓝色光晕。
- 运行中项目胶囊增加低透明度蓝色背景与蓝色描边；完成和报错维持原有语义色。
- 项目名称保持白色或系统主文字色，确保浅色与深色菜单栏都可读。

## 每日活动提示

- 继续使用 macOS 原生延迟 Help 提示，鼠标停留片刻后出现。
- 有活动的格子展示日期、Token 数、会话数。
- 无活动的格子展示日期和“无活动”。
- 日期使用中文 `M月d日` 格式，数据使用现有紧凑 Token 格式。

## 登录自启动

- 使用当前用户的 LaunchAgent，不请求管理员权限。
- 标签为 `com.dafeng.codexmonitor.loginitem`。
- 登录后运行 `/Users/lele/Desktop/大丰数艺/Codex额度/dist/Codex Monitor.app/Contents/MacOS/CodexMonitor`。
- 安装后立即加载，并通过 `launchctl print` 验证。

## 验证

- 单元测试覆盖运行中颜色令牌和每日活动提示文本。
- 完整 Swift 测试通过后重新打包和签名。
- 启动新包并确认 CPU 回落。
- LaunchAgent plist 通过 `plutil`，且服务可被 launchctl 查询。
