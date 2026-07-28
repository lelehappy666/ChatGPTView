# Codex Monitor 产品型 README 设计规格

## 目标

为仓库根目录新增一份中文 `README.md`，以 macOS 版本为主要展示对象，用产品官网式的视觉层级介绍 Codex Monitor，同时提供真实、可执行的安装构建说明。Windows 版本作为跨平台支持单独介绍并链接现有文档。

## 受众

- 希望快速了解 Codex Monitor 用途的普通用户。
- 想从源码构建 macOS 应用的开发者。
- 希望了解 Windows 版本能力和打包方式的用户。

## 视觉方向

- 整体采用克制、现代的产品展示风格，与应用的黑色面板和紫色强调色保持一致。
- 顶部使用居中的应用图标、产品名称和一句中文定位。
- 徽章只展示有实际信息价值的内容：macOS 14+、Swift 6、当前版本 0.1.20、Windows 11。
- 使用仓库内已有图片，避免依赖外部图片服务：
  - `Resources/AppIconPreview.png`
  - `docs/designs/macos-notch-pages-v1.png`
  - `docs/designs/github-activity-page-v1.png`
- 图片使用相对路径，确保 GitHub 仓库页面能够直接显示。

## 页面结构

### 1. 首屏

- 居中展示应用图标。
- 标题为 `Codex Monitor`。
- 副标题为“一眼掌握 Codex 额度、活动与项目状态”。
- 用一段简短文字说明它是原生 macOS 菜单栏应用，读取本机 Codex 会话数据，不打断当前工作。
- 展示四个状态徽章。
- 展示周额度、每日活动、统计总览和 GitHub 活跃四页刘海设计总览图作为主视觉。

### 2. 核心能力

用紧凑表格展示六项真实能力：

1. 周额度：剩余额度、已用比例、重置时间和手动刷新。
2. 每日活动：Token、会话、平均值、连续使用和热力图。
3. 项目分析：7 天、30 天、全部范围与项目排名。
4. 统计总览：累计、峰值、最长任务和连续天数。
5. GitHub 活跃：贡献热力图和最近更新的六个仓库。
6. 完成通知：识别真实顶层会话完成状态并发送系统通知。

### 3. GitHub 活跃

- 展示授权前与授权后的设计图。
- 说明 GitHub 功能需要用户主动绑定。
- 说明凭据保存在 macOS 钥匙串中。
- 不承诺仓库未实现的权限范围或云端同步能力。

### 4. 快速开始

写明运行环境：

- macOS 14 或更高版本。
- Xcode 及 Swift 6 工具链。
- 本机至少产生过一个 Codex 会话。

提供从源码构建和打包命令：

```bash
git clone https://github.com/lelehappy666/ChatGPTView.git
cd ChatGPTView
swift test
bash scripts/package-app.sh
open "dist/Codex Monitor.app"
```

说明打包结果位于 `dist/Codex Monitor.app`。

### 5. 工作方式与隐私

- 默认读取 `~/.codex/sessions`。
- 本地解析额度、Token、活动、项目和统计信息。
- GitHub 凭据保存到系统钥匙串。
- 没有可靠额度数据时显示不可用状态，不估算或伪造。

### 6. Windows 11

- 简要说明 Windows 版本使用 .NET 8 和 Windows Forms。
- 支持顶部紧凑胶囊、四页数据、系统托盘、完成通知和开机启动。
- 链接到 `Windows/README.md` 获取完整构建与使用说明。
- 不让 Windows 内容抢占 macOS 主视觉。

### 7. 开发说明

- 列出 Swift、SwiftUI、AppKit、XCTest，以及 Windows 的 .NET 8 / Windows Forms。
- 提供 `swift test` 测试命令。
- 用简洁目录树介绍 `Sources`、`Tests`、`Resources`、`Windows`、`docs/designs` 和 `scripts`。

### 8. 结尾

- 提供问题反馈链接，指向仓库 Issues 页面。
- 保留许可证提示；仓库当前没有许可证文件，因此使用中性文字“许可证信息将在仓库中另行说明”，不虚构开源许可证。

## 内容约束

- 全文使用中文。
- 不使用无法长期维护的动态统计或虚构下载量。
- 不写“完全免费”“绝对隐私”等无法由代码证明的宣传语。
- 不使用外部 CDN、远程图床或第三方生成图片。
- 不把设计稿表述为与当前运行效果像素级完全一致，图片说明使用“界面设计预览”。
- Markdown 在 GitHub 上无需 HTML/CSS 即可清晰阅读；仅在首屏居中排版和图片尺寸控制时使用少量安全 HTML。

## 验收标准

- 仓库根目录存在 `README.md`。
- 所有图片和内部链接均指向实际存在的仓库文件。
- 构建命令与当前脚本及仓库地址一致。
- 版本信息为 `0.1.20`。
- README 以 Mac 为主，Windows 仅作为独立支持章节。
- Markdown 结构清晰，桌面端与移动端均能正常阅读。
