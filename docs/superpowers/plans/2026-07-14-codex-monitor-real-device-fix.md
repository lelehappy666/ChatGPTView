# Codex Monitor 真机修复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复真实 Codex 数据无法显示和手动刷新无反馈的问题，并交付放大至 `420 × 260` 的清晰刘海窗口。

**Architecture:** 使用流式 JSONL 解析和基于文件元数据的增量缓存减少扫描成本；由 MonitorStore 串行合并刷新请求并发布可观察刷新状态。UI 只消费 MonitorSnapshot 和刷新状态，刘海布局通过统一尺寸常量放大。

**Tech Stack:** Swift 6、SwiftUI、AppKit、FSEvents、XCTest、Swift Package Manager。

## Global Constraints

- macOS 14.0 及以上。
- 数据只读取本机 `~/.codex/sessions`，不得上传或修改原始日志。
- 刘海窗口固定为 `420 × 260`，保留三页结构。
- 所有数据必须完整可见，统计页底部至少保留 14 px 安全间距。
- 所有行为变更遵循 RED、GREEN、REFACTOR。

---

### Task 1: 修复真实会话解析

**Files:**
- Modify: `Sources/CodexMonitor/Data/CodexJSONL.swift`
- Modify: `Sources/CodexMonitor/Data/SessionScanner.swift`
- Test: `Tests/CodexMonitorTests/JSONLDecoderTests.swift`

**Interfaces:**
- Produces: `SessionScanner.parseFile(_:) throws -> SessionSummary?`
- Produces: `RateLimits.weeklyWindow: RateWindow?`

- [ ] **Step 1: 写入失败测试**

新增测试日志，使 `secondary.window_minutes` 为 `10080`，断言可解析周额度；新增大文件逐行解析测试。

- [ ] **Step 2: 验证测试因 secondary 未支持而失败**

Run: `xcrun swift test --disable-sandbox --filter JSONLDecoderTests`

- [ ] **Step 3: 最小实现**

为 RateLimits 解码 primary/secondary，并用 `weeklyWindow` 选择 10080 分钟窗口；用 `FileHandle.read(upToCount:)` 分块切行，逐条交给现有 envelope 解码器。

- [ ] **Step 4: 验证聚焦测试通过**

Run: `xcrun swift test --disable-sandbox --filter JSONLDecoderTests`

### Task 2: 增量缓存与刷新状态

**Files:**
- Modify: `Sources/CodexMonitor/Data/SessionScanner.swift`
- Modify: `Sources/CodexMonitor/Data/MonitorStore.swift`
- Modify: `Sources/CodexMonitor/MenuBar/MenuBarController.swift`
- Modify: `Sources/CodexMonitor/MenuBar/MenuBarContentView.swift`
- Test: `Tests/CodexMonitorTests/MonitorStoreTests.swift`

**Interfaces:**
- Produces: `ScanCache`，以路径、大小、修改时间保存 `SessionSummary?`
- Produces: `MonitorStore.refreshState: RefreshState`
- Consumes: `MonitorStore.requestRefresh(force:)`

- [ ] **Step 1: 写入失败测试**

断言未变化文件不重复解析、刷新期间状态为 refreshing、重复请求不会并行扫描、完成后状态为 updated。

- [ ] **Step 2: 验证测试失败**

Run: `xcrun swift test --disable-sandbox --filter MonitorStoreTests`

- [ ] **Step 3: 最小实现**

增加缓存扫描器和单一刷新循环；FSEvents 使用普通增量刷新，菜单命令使用 `force: true` 并更新菜单项标题。

- [ ] **Step 4: 验证聚焦测试通过**

Run: `xcrun swift test --disable-sandbox --filter MonitorStoreTests`

### Task 3: 放大刘海界面

**Files:**
- Modify: `Sources/CodexMonitor/Notch/NotchLayout.swift`
- Modify: `Sources/CodexMonitor/Notch/WeeklyQuotaPage.swift`
- Modify: `Sources/CodexMonitor/Notch/DailyActivityPage.swift`
- Modify: `Sources/CodexMonitor/Notch/StatisticsPage.swift`
- Modify: `Sources/CodexMonitor/Notch/ActivityHeatmap.swift`
- Test: `Tests/CodexMonitorTests/LayoutContractTests.swift`

**Interfaces:**
- Produces: `NotchLayout.size == CGSize(width: 420, height: 260)`

- [ ] **Step 1: 将布局契约测试改为期望 420 × 260 和 14 px 安全间距**

- [ ] **Step 2: 验证布局契约失败**

Run: `xcrun swift test --disable-sandbox --filter LayoutContractTests`

- [ ] **Step 3: 调整统一尺寸、字号、间距和热力格尺寸**

保持三页内容固定在页面可用高度内，避免依靠裁切隐藏内容。

- [ ] **Step 4: 验证布局测试通过**

Run: `xcrun swift test --disable-sandbox --filter LayoutContractTests`

### Task 4: 真实数据性能与最终打包

**Files:**
- Modify: `scripts/package-app.sh`（仅在打包验证需要时）

**Interfaces:**
- Produces: `dist/Codex Monitor.app`

- [ ] **Step 1: 运行完整测试套件**

Run: `xcrun swift test --disable-sandbox`
Expected: 全部测试 0 failures。

- [ ] **Step 2: 使用真实 `~/.codex/sessions` 运行扫描性能检查**

Expected: 扫描完成并得到非空项目、每日活动和周额度，进程 CPU 在完成后回落。

- [ ] **Step 3: Release 打包与签名验证**

Run: `bash scripts/package-app.sh`
Run: `codesign --verify --deep --strict 'dist/Codex Monitor.app'`

- [ ] **Step 4: 替换运行中的旧版本并启动最终包**

Expected: 最终包进程常驻，菜单栏和刘海窗口展示真实数据。

- [ ] **Step 5: 提交**

Run: `git add Sources Tests docs scripts && git commit -m 'fix: 修复真机数据刷新并放大刘海窗口'`
