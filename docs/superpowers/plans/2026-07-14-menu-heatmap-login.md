# 菜单状态、活动提示与登录启动实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 提高运行中项目在菜单栏的辨识度，为每日活动格增加完整延迟提示，并把最终应用设置为当前用户登录自启动。

**Architecture:** 新增可测试的视觉令牌与活动提示格式器，SwiftUI 视图只负责将令牌渲染为颜色和 Help。登录启动使用独立 LaunchAgent plist 指向最终 app 二进制，不修改系统级设置。

**Tech Stack:** Swift 6、SwiftUI、XCTest、launchd、Swift Package Manager。

## Global Constraints

- 运行中颜色固定为 `#0A84FF`。
- 活动提示必须包含日期、Token 和会话数。
- 自启动标签固定为 `com.dafeng.codexmonitor.loginitem`。
- 自启动仅安装到当前用户，不请求管理员权限。

---

### Task 1: 可测试视觉令牌与活动提示

**Files:**
- Create: `Sources/CodexMonitor/UI/VisualTokens.swift`
- Modify: `Sources/CodexMonitor/MenuBar/MenuBarContentView.swift`
- Modify: `Sources/CodexMonitor/Notch/ActivityHeatmap.swift`
- Test: `Tests/CodexMonitorTests/VisualFeedbackTests.swift`

**Interfaces:**
- Produces: `RGBToken.runningAccent`
- Produces: `ActivityTooltip.text(for:calendar:) -> String`

- [ ] **Step 1: 写入失败测试**

```swift
XCTAssertEqual(RGBToken.runningAccent.hex, "0A84FF")
XCTAssertEqual(ActivityTooltip.text(for: day, calendar: calendar), "7月14日 · 14.2 万 Token · 3 个会话")
```

- [ ] **Step 2: 运行测试并确认因接口不存在而失败**

Run: `xcrun swift test --disable-sandbox --filter VisualFeedbackTests`

- [ ] **Step 3: 最小实现令牌和提示格式器**

```swift
static let runningAccent = RGBToken(red: 10, green: 132, blue: 255)
static func text(for day: UsageDay, calendar: Calendar) -> String
```

- [ ] **Step 4: 在 SwiftUI 中应用颜色、8 px 状态点、蓝色胶囊背景与完整 Help**

- [ ] **Step 5: 运行聚焦测试并确认通过**

Run: `xcrun swift test --disable-sandbox --filter VisualFeedbackTests`

### Task 2: 打包与用户级登录启动

**Files:**
- Create: `scripts/com.dafeng.codexmonitor.loginitem.plist`

**Interfaces:**
- Produces: `~/Library/LaunchAgents/com.dafeng.codexmonitor.loginitem.plist`

- [ ] **Step 1: 运行完整测试**

Run: `xcrun swift test --disable-sandbox`
Expected: 0 failures。

- [ ] **Step 2: 重新打包并验证签名**

Run: `bash scripts/package-app.sh`
Run: `codesign --verify --deep --strict 'dist/Codex Monitor.app'`

- [ ] **Step 3: 安装并加载 LaunchAgent**

将 plist 复制到 `~/Library/LaunchAgents`，执行 `launchctl bootstrap gui/501 <plist>`。

- [ ] **Step 4: 验证服务与应用**

Run: `launchctl print gui/501/com.dafeng.codexmonitor.loginitem`
Expected: 服务存在且程序路径指向最终 app 二进制。

- [ ] **Step 5: 提交**

Run: `git add Sources Tests scripts docs && git commit -m 'feat: 增强运行状态并支持登录自启动'`
