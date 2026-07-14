# 通知权限启动检测实施计划

> **供执行人员使用：** 必须使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans`，按任务逐项实施。本计划使用复选框跟踪进度。

**目标：** 每次启动检查 Codex Monitor 的通知横幅和声音权限，仅在权限不完整时申请授权或引导用户打开系统设置。

**架构：** 使用纯值类型 `NotificationPermissionPolicy` 将系统权限快照转换为启动动作，以便完整测试。`ProjectCompletionNotifier` 负责读取 `UNUserNotificationCenter` 设置、请求首次授权、显示 AppKit 提示并打开系统通知设置；`AppDelegate` 每次启动调用一次异步检查。

**技术栈：** Swift 6.2、AppKit、UserNotifications、XCTest、macOS 14+

## 全局约束

- 所有文档使用中文。
- 所有 Git 提交信息使用中文。
- 已授权且横幅、声音开启时保持静默。
- 只有用户点击按钮时才打开系统设置。
- 不修改项目完成检测和通知正文。

---

### 任务一：用测试固化通知权限决策

**文件：**
- 修改：`Tests/CodexMonitorTests/ProjectCompletionNotifierTests.swift`
- 修改：`Sources/CodexMonitor/Notifications/ProjectCompletionNotifier.swift`

**接口：**
- 输出：`NotificationPermissionSnapshot`
- 输出：`NotificationPermissionAction`
- 输出：`NotificationPermissionPolicy.action(for:)`

- [ ] **步骤一：添加失败测试**

```swift
func testUndeterminedPermissionRequestsAuthorization() {
    XCTAssertEqual(
        NotificationPermissionPolicy.action(for: .init(
            authorization: .notDetermined,
            alertsEnabled: false,
            soundsEnabled: false
        )),
        .requestAuthorization
    )
}

func testCompletePermissionNeedsNoAction() {
    XCTAssertEqual(
        NotificationPermissionPolicy.action(for: .init(
            authorization: .authorized,
            alertsEnabled: true,
            soundsEnabled: true
        )),
        .none
    )
}

func testIncompletePermissionPromptsForSettings() {
    let snapshots = [
        NotificationPermissionSnapshot(
            authorization: .denied,
            alertsEnabled: false,
            soundsEnabled: false
        ),
        NotificationPermissionSnapshot(
            authorization: .authorized,
            alertsEnabled: false,
            soundsEnabled: true
        ),
        NotificationPermissionSnapshot(
            authorization: .authorized,
            alertsEnabled: true,
            soundsEnabled: false
        )
    ]
    XCTAssertEqual(
        snapshots.map(NotificationPermissionPolicy.action(for:)),
        [.promptForSettings, .promptForSettings, .promptForSettings]
    )
}
```

- [ ] **步骤二：运行测试并确认失败**

运行：

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/tmp/codex-monitor-clang-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/tmp/codex-monitor-swift-cache \
  swift test --disable-sandbox --filter ProjectCompletionNotifierTests
```

预期：因权限快照、动作和策略尚不存在而失败。

- [ ] **步骤三：实现最小权限策略**

```swift
enum NotificationAuthorizationState: Equatable {
    case notDetermined
    case denied
    case authorized
}

struct NotificationPermissionSnapshot: Equatable {
    let authorization: NotificationAuthorizationState
    let alertsEnabled: Bool
    let soundsEnabled: Bool
}

enum NotificationPermissionAction: Equatable {
    case none
    case requestAuthorization
    case promptForSettings
}

enum NotificationPermissionPolicy {
    static func action(for snapshot: NotificationPermissionSnapshot) -> NotificationPermissionAction {
        switch snapshot.authorization {
        case .notDetermined:
            return .requestAuthorization
        case .denied:
            return .promptForSettings
        case .authorized:
            return snapshot.alertsEnabled && snapshot.soundsEnabled
                ? .none
                : .promptForSettings
        }
    }
}
```

- [ ] **步骤四：运行聚焦测试并确认通过**

运行与步骤二相同的命令。

预期：通知文案与权限策略测试全部通过。

---

### 任务二：实现每次启动检测和设置引导

**文件：**
- 修改：`Sources/CodexMonitor/Notifications/ProjectCompletionNotifier.swift`
- 修改：`Sources/CodexMonitor/App/AppDelegate.swift`

**接口：**
- 输入：`UNNotificationSettings`
- 输出：`ProjectCompletionNotifier.ensureAuthorization() async`

- [ ] **步骤一：将系统设置转换为权限快照**

```swift
private static func snapshot(from settings: UNNotificationSettings) -> NotificationPermissionSnapshot {
    let authorization: NotificationAuthorizationState
    switch settings.authorizationStatus {
    case .notDetermined:
        authorization = .notDetermined
    case .authorized, .provisional, .ephemeral:
        authorization = .authorized
    case .denied:
        authorization = .denied
    @unknown default:
        authorization = .denied
    }
    return NotificationPermissionSnapshot(
        authorization: authorization,
        alertsEnabled: settings.alertSetting == .enabled,
        soundsEnabled: settings.soundSetting == .enabled
    )
}
```

- [ ] **步骤二：实现异步启动检查**

```swift
func ensureAuthorization() async {
    let settings = await center.notificationSettings()
    switch NotificationPermissionPolicy.action(for: Self.snapshot(from: settings)) {
    case .none:
        return
    case .requestAuthorization:
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        if !granted {
            await showSettingsPrompt()
        }
    case .promptForSettings:
        await showSettingsPrompt()
    }
}
```

- [ ] **步骤三：实现中文提示和设置跳转**

```swift
@MainActor
private func showSettingsPrompt() {
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.messageText = "需要开启通知权限"
    alert.informativeText = "Codex Monitor 需要通知权限，才能在项目完成时提醒你。请在系统设置中开启通知横幅和声音。"
    alert.alertStyle = .informational
    alert.addButton(withTitle: "打开通知设置")
    alert.addButton(withTitle: "稍后")
    guard alert.runModal() == .alertFirstButtonReturn else { return }
    openNotificationSettings()
}

@MainActor
private func openNotificationSettings() {
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.dafeng.codexmonitor"
    let values = [
        "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleIdentifier)",
        "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
    ]
    for value in values {
        guard let url = URL(string: value) else { continue }
        if NSWorkspace.shared.open(url) { return }
    }
}
```

- [ ] **步骤四：修改启动调用**

```swift
Task { [completionNotifier] in
    await completionNotifier.ensureAuthorization()
}
```

删除旧的无条件 `completionNotifier.requestAuthorization()` 调用。

- [ ] **步骤五：运行完整测试**

使用任务一步骤二的环境变量运行：`swift test --disable-sandbox`。

预期：全部测试通过，零失败。

---

### 任务三：打包、更新和提交

**文件：**
- 生成：`dist/Codex Monitor.app`

- [ ] **步骤一：重新打包并验证签名**

```bash
bash scripts/package-app.sh
codesign --verify --deep --strict --verbose=2 'dist/Codex Monitor.app'
```

预期：应用包生成成功，签名有效。

- [ ] **步骤二：重启 LaunchAgent**

结束旧 `CodexMonitor` 进程，运行：

```bash
launchctl kickstart gui/501/com.dafeng.codexmonitor.loginitem
```

预期：LaunchAgent 状态为 `running`，且只有一个新进程。

- [ ] **步骤三：提交实现**

```bash
git add Sources Tests docs/superpowers/plans/2026-07-14-notification-permission-check.md
git commit -m "功能：增加通知权限启动检测"
```
