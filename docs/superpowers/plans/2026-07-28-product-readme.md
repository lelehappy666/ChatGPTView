# Codex Monitor 产品型 README 实施计划

> **面向执行代理：** 必须使用 `superpowers:executing-plans` 或 `superpowers:subagent-driven-development` 按任务执行。

**目标：** 在仓库根目录创建一份以 macOS 为主、Windows 为补充的中文产品型 `README.md`。

**架构：** README 使用仓库内已有应用图标和两张设计图形成产品展示层级，再用核心能力、快速开始、隐私、Windows 支持和开发说明提供可执行信息。所有资源使用仓库相对路径，不依赖外部图床。

**技术栈：** GitHub Flavored Markdown、少量安全 HTML、Swift Package Manager、现有 Bash 打包脚本。

## 全局约束

- 全文使用中文。
- Mac 为主视觉，Windows 作为独立跨平台章节。
- 当前版本必须写为 `0.1.20`。
- 只引用仓库中实际存在的图片和文件。
- 不虚构许可证、下载量、权限范围或产品能力。
- 构建命令必须与当前仓库地址及脚本一致。

---

### 任务一：创建产品型 README

**文件：**

- 新建：`README.md`
- 引用：`Resources/AppIconPreview.png`
- 引用：`docs/designs/macos-notch-pages-v1.png`
- 引用：`docs/designs/github-activity-page-v1.png`
- 链接：`Windows/README.md`

**产出结构：**

- 居中首屏、产品图标、标题、副标题和状态徽章。
- macOS 四页刘海面板主视觉。
- 六项核心能力表格。
- GitHub 授权前后设计预览。
- 快速开始、工作方式与隐私、Windows 11、开发说明和问题反馈。

- [ ] **步骤 1：编写首屏和主视觉**

使用以下首屏结构：

```markdown
<p align="center">
  <img src="Resources/AppIconPreview.png" width="112" alt="Codex Monitor 应用图标">
</p>

<h1 align="center">Codex Monitor</h1>

<p align="center">
  一眼掌握 Codex 额度、活动与项目状态
</p>
```

徽章展示 macOS 14+、Swift 6、版本 0.1.20 和 Windows 11。

- [ ] **步骤 2：编写核心能力与 GitHub 展示**

以六行 Markdown 表格描述周额度、每日活动、项目分析、统计总览、GitHub 活跃和完成通知。在 GitHub 章节插入：

```markdown
![GitHub 活跃授权前后界面设计预览](docs/designs/github-activity-page-v1.png)
```

- [ ] **步骤 3：编写安装、隐私、Windows 和开发说明**

快速开始必须包含：

```bash
git clone https://github.com/lelehappy666/ChatGPTView.git
cd ChatGPTView
swift test
bash scripts/package-app.sh
open "dist/Codex Monitor.app"
```

Windows 章节链接：

```markdown
[查看 Windows 11 完整使用与打包说明](Windows/README.md)
```

- [ ] **步骤 4：检查文案一致性**

确认全文不出现虚构许可证、下载地址、权限范围、外部图片或与当前版本不一致的数字。

### 任务二：验证 README 并提交

**文件：**

- 验证：`README.md`
- 验证：`Resources/Info.plist`
- 验证：README 引用的所有本地资源

- [ ] **步骤 1：验证版本一致**

运行：

```bash
plutil -extract CFBundleShortVersionString raw Resources/Info.plist
rg -n "0\\.1\\.20" README.md
```

预期：两处版本均为 `0.1.20`。

- [ ] **步骤 2：验证本地图片和内部链接**

运行：

```bash
test -f Resources/AppIconPreview.png
test -f docs/designs/macos-notch-pages-v1.png
test -f docs/designs/github-activity-page-v1.png
test -f Windows/README.md
```

预期：所有命令退出状态为 0。

- [ ] **步骤 3：验证 Markdown 基础结构**

运行：

```bash
rg -n "^#|^##|^\\| |docs/designs/|Windows/README.md|scripts/package-app.sh" README.md
git diff --check
```

预期：主要章节、功能表格、图片、Windows 链接和打包命令均存在，且无空白错误。

- [ ] **步骤 4：中文提交**

```bash
git add README.md
git commit -m "文档：新增产品型中文说明"
```
