# 项目状态过期与应用图标实施计划

> **供执行人员使用：** 必须使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans`，按任务逐项实施。本计划使用复选框跟踪进度。

**目标：** 统一隐藏 60 秒无操作的所有项目状态，并为 Codex Monitor 生成和打包原创 macOS 应用图标。

**架构：** `ProjectVisibilityPolicy` 作为数据聚合和菜单栏共用的时间规则，菜单栏每 4 秒主动清理过期项目。图标由可重复运行的 Swift/Core Graphics 脚本生成主图和 `.icns`，通过 Info.plist 与打包脚本写入应用包。

**技术栈：** Swift 6.2、SwiftUI、AppKit、Core Graphics、XCTest、macOS 14+

## 全局约束

- 所有文档使用中文。
- 所有 Git 提交信息使用中文。
- 所有项目状态统一使用 60 秒过期时间。
- 项目过期后顶部不显示“暂无项目”。
- 完成通知按项目更新时间去重，首次真实快照只建立基线。
- 图标不使用 OpenAI 或 ChatGPT 官方商标图形。

---

### 任务一：用测试固化 60 秒统一过期规则

**文件：**
- 修改：`Sources/CodexMonitor/Domain/MonitorModels.swift`
- 修改：`Sources/CodexMonitor/Data/UsageAggregator.swift`
- 修改：`Sources/CodexMonitor/MenuBar/MenuBarContentView.swift`
- 修改：`Tests/CodexMonitorTests/UsageAggregatorTests.swift`
- 新建：`Tests/CodexMonitorTests/ProjectVisibilityTests.swift`

**接口：**
- 输出：`ProjectVisibilityPolicy.inactivityTimeout = 60`
- 输出：`ProjectVisibilityPolicy.isVisible(updatedAt:now:)`
- 输出：`Array<ProjectActivity>.visibleForMenu(at:)`

- [ ] **步骤一：添加失败测试**

```swift
func testAllStatesExpireAtSixtySeconds() {
    let now = Date(timeIntervalSince1970: 1_000)
    let projects = [
        project("运行", .running, now.addingTimeInterval(-60)),
        project("完成", .completed, now.addingTimeInterval(-60)),
        project("报错", .failed, now.addingTimeInterval(-60))
    ]
    XCTAssertTrue(projects.visibleForMenu(at: now).isEmpty)
}

func testAllStatesRemainVisibleBeforeSixtySeconds() {
    let now = Date(timeIntervalSince1970: 1_000)
    let projects = [
        project("运行", .running, now.addingTimeInterval(-59.9)),
        project("完成", .completed, now.addingTimeInterval(-59.9)),
        project("报错", .failed, now.addingTimeInterval(-59.9))
    ]
    XCTAssertEqual(projects.visibleForMenu(at: now).count, 3)
}
```

在聚合测试中使用三个 60 秒前更新的不同状态会话，并断言 `snapshot.projects` 为空。

- [ ] **步骤二：运行测试并确认失败**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/tmp/codex-monitor-clang-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/tmp/codex-monitor-swift-cache \
  swift test --disable-sandbox --filter 'ProjectVisibilityTests|UsageAggregatorTests'
```

预期：因统一可见性策略不存在且旧逻辑只过滤 30 分钟前的完成状态而失败。

- [ ] **步骤三：实现统一策略**

```swift
enum ProjectVisibilityPolicy {
    static let inactivityTimeout: TimeInterval = 60

    static func isVisible(updatedAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(updatedAt) < inactivityTimeout
    }
}

extension Array where Element == ProjectActivity {
    func visibleForMenu(at now: Date = .now) -> [ProjectActivity] {
        filter { ProjectVisibilityPolicy.isVisible(updatedAt: $0.updatedAt, now: now) }
    }
}
```

聚合层先生成 `ProjectActivity`，再调用 `.visibleForMenu(at: now).sortedForMenu`，删除旧的完成状态 30 分钟判断。

- [ ] **步骤四：让菜单栏主动清理过期项目**

```swift
.onReceive(timer) { now in
    ticker.projects = store.snapshot.projects.visibleForMenu(at: now)
    withAnimation(.easeInOut(duration: 0.28)) {
        ticker.advance()
    }
}
.onReceive(store.$snapshot) { snapshot in
    ticker.projects = snapshot.projects.visibleForMenu()
}
```

删除空项目时的“暂无项目”文字分支。

- [ ] **步骤五：运行聚焦测试并确认通过**

运行与步骤二相同的命令。

预期：60 秒边界、三种状态和聚合测试全部通过。

---

### 任务二：修复完成通知准确性

**文件：**
- 修改：`Sources/CodexMonitor/Notifications/ProjectCompletionDetector.swift`
- 修改：`Sources/CodexMonitor/App/AppDelegate.swift`
- 修改：`Tests/CodexMonitorTests/ProjectCompletionDetectorTests.swift`

- [ ] **步骤一：添加失败测试**

覆盖首次完成快照不提醒、空基线后的快速完成提醒、相同完成时间不重复提醒，以及更晚完成时间再次提醒。

- [ ] **步骤二：运行测试并确认失败**

运行 `swift test --disable-sandbox --filter ProjectCompletionDetectorTests`，确认旧的“必须先观察到进行中”逻辑会漏报快速完成任务。

- [ ] **步骤三：按更新时间实现完成事件去重**

首个真实快照建立项目更新时间基线；后续完成项目的更新时间大于已记录时间时触发一次提醒，并保留历史时间防止项目暂时消失后重复提醒。

- [ ] **步骤四：跳过发布器初始空值并验证**

在 `AppDelegate` 的快照订阅中跳过 `@Published` 自动发送的初始空快照，使首次刷新结果成为历史基线。再次运行专项测试并确认通过。

---

### 任务三：生成原创 macOS 应用图标

**文件：**
- 新建：`scripts/generate-app-icon.swift`
- 生成：`Resources/AppIconPreview.png`
- 生成：`Resources/AppIcon.icns`

**视觉构成：**
- 深色圆角方形渐变底。
- 顶部黑色刘海和微型镜头点。
- 中央紫色环形额度指示符。
- 环形内部使用简化活动柱形。
- 右侧使用橙色运行状态点。

- [ ] **步骤一：编写可重复生成脚本**

脚本使用 `NSBitmapImageRep` 和 `CGContext` 绘制 1024×1024 透明 PNG，随后生成以下 iconset 文件：

```text
icon_16x16.png
icon_16x16@2x.png
icon_32x32.png
icon_32x32@2x.png
icon_128x128.png
icon_128x128@2x.png
icon_256x256.png
icon_256x256@2x.png
icon_512x512.png
icon_512x512@2x.png
```

脚本最后按 ICNS 规范写入 `icp4` 至 `ic10` 的 PNG 分块：

```swift
icns.append("icns".data(using: .ascii)!)
icns.append(totalLength.bigEndianData)
icns.append(pngChunks)
```

- [ ] **步骤二：运行图标生成脚本**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift scripts/generate-app-icon.swift
```

预期：生成 1024 像素预览图和有效 ICNS 文件。

- [ ] **步骤三：目视检查图标**

使用本地图片查看工具打开 `Resources/AppIconPreview.png`，确认透明外角、图形居中、无裁切且缩小时仍清晰。

---

### 任务四：声明并打包图标资源

**文件：**
- 修改：`Resources/Info.plist`
- 修改：`scripts/package-app.sh`
- 修改：`Tests/CodexMonitorTests/AppIntegrationTests.swift`

- [ ] **步骤一：添加元数据失败测试**

```swift
func testAppMetadataDeclaresPackagedIcon() throws {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let data = try Data(contentsOf: root.appendingPathComponent("Resources/Info.plist"))
    let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    XCTAssertEqual(plist?["CFBundleIconFile"] as? String, "AppIcon")
    XCTAssertTrue(FileManager.default.fileExists(
        atPath: root.appendingPathComponent("Resources/AppIcon.icns").path
    ))
}
```

- [ ] **步骤二：运行测试并确认失败**

运行：`swift test --disable-sandbox --filter AppIntegrationTests`，并使用任务一相同的 Xcode 环境变量。

预期：Info.plist 尚未声明图标而失败。

- [ ] **步骤三：声明和复制资源**

在 Info.plist 中增加：

```xml
<key>CFBundleIconFile</key>
<string>AppIcon</string>
```

在打包脚本复制 Info.plist 后增加：

```bash
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
```

- [ ] **步骤四：运行完整测试**

使用任务一的 Xcode 环境变量运行 `swift test --disable-sandbox`。

预期：所有测试通过，零失败。

---

### 任务五：打包、验证和更新运行应用

- [ ] **步骤一：重新打包并验证图标与签名**

```bash
bash scripts/package-app.sh
test -f 'dist/Codex Monitor.app/Contents/Resources/AppIcon.icns'
codesign --verify --deep --strict --verbose=2 'dist/Codex Monitor.app'
```

- [ ] **步骤二：重启 LaunchAgent**

结束旧进程后运行：

```bash
launchctl kickstart gui/501/com.dafeng.codexmonitor.loginitem
```

预期：LaunchAgent 状态为 `running`，只存在一个新版进程。

- [ ] **步骤三：提交实现**

```bash
git add Sources Tests Resources scripts docs/superpowers/plans/2026-07-14-project-expiry-app-icon.md
git commit -m "功能：增加应用图标并统一项目过期时间"
```
