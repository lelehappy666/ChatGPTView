# Immediate Heatmap and Running Status Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show daily activity data immediately on hover and make the menu-bar running state unmistakable.

**Architecture:** Keep hover state local to `ActivityHeatmap` and render the hovered day's formatted data in a reserved footer beneath the grid, so no content is covered. Centralize the running accent in `RGBToken`; render only the running-state label as a solid orange badge while preserving existing project ticker behavior.

**Tech Stack:** Swift 6.2, SwiftUI, XCTest, macOS 14+, Swift Package Manager

## Global Constraints

- Keep the 420 × 260 notch window and the existing 56-day grid.
- Do not change scanner, quota, activity, or project-state data sources.
- Running accent is `#FF9F0A`.
- Hover feedback is immediate and must not use delayed `.help` presentation.

---

### Task 1: Lock visual behavior with tests

**Files:**
- Modify: `Tests/CodexMonitorTests/VisualFeedbackTests.swift`
- Modify: `Sources/CodexMonitor/UI/VisualTokens.swift`

**Interfaces:**
- Consumes: `RGBToken.runningAccent`, `ActivityTooltip.text(for:calendar:)`
- Produces: `ActivityTooltip.presentationDelayMilliseconds: Int`

- [ ] **Step 1: Write failing tests**

```swift
func testRunningAccentUsesOpaqueHighContrastOrange() {
    XCTAssertEqual(RGBToken.runningAccent.hex, "FF9F0A")
}

func testActivityHoverPresentationHasNoDelay() {
    XCTAssertEqual(ActivityTooltip.presentationDelayMilliseconds, 0)
}
```

- [ ] **Step 2: Run focused tests and verify RED**

Run: `swift test --filter VisualFeedbackTests`

Expected: failures because the current accent is `0A84FF` and `presentationDelayMilliseconds` is absent.

- [ ] **Step 3: Add the minimal behavior tokens**

```swift
static let runningAccent = RGBToken(red: 255, green: 159, blue: 10)

enum ActivityTooltip {
    static let presentationDelayMilliseconds = 0

    static func text(
        for day: UsageDay,
        calendar: Calendar = .current
    ) -> String {
        let components = calendar.dateComponents([.month, .day], from: day.date)
        let dateText = "\(components.month ?? 0)月\(components.day ?? 0)日"
        guard day.tokens > 0 || day.sessions > 0 else {
            return "\(dateText) · 无活动"
        }
        return "\(dateText) · \(MetricFormatter.tokens(day.tokens)) Token · \(day.sessions) 个会话"
    }
}
```

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `swift test --filter VisualFeedbackTests`

Expected: all `VisualFeedbackTests` pass.

### Task 2: Render immediate hover feedback and solid running badge

**Files:**
- Modify: `Sources/CodexMonitor/Notch/ActivityHeatmap.swift`
- Modify: `Sources/CodexMonitor/Notch/DailyActivityPage.swift`
- Modify: `Sources/CodexMonitor/MenuBar/MenuBarContentView.swift`

**Interfaces:**
- Consumes: `ActivityTooltip.text(for:)`, `RGBToken.runningAccent.color`
- Produces: immediate local `hoveredDay: UsageDay?` UI state and a non-overlapping heatmap footer

- [ ] **Step 1: Replace delayed native help with direct hover state**

Add `@State private var hoveredDay: UsageDay?`, set it directly inside each cell's `.onHover`, remove `.help`, and show `ActivityTooltip.text(for:)` in a fixed-height footer below the grid:

```swift
@State private var hoveredDay: UsageDay?

VStack(alignment: .leading, spacing: 5) {
    LazyHGrid(rows: rows, spacing: 3) {
        ForEach(Array(paddedDays.enumerated()), id: \.offset) { _, day in
            RoundedRectangle(cornerRadius: 2)
                .fill(color(for: day.tokens))
                .frame(width: 11, height: 11)
                .onHover { isHovered in
                    hoveredDay = isHovered ? day : (hoveredDay == day ? nil : hoveredDay)
                }
        }
    }
    .frame(width: 142, height: 95, alignment: .leading)

    Group {
        if let hoveredDay {
            Text(ActivityTooltip.text(for: hoveredDay))
                .lineLimit(1)
        } else {
            ActivityLegend()
        }
    }
    .font(.system(size: 9, weight: hoveredDay == nil ? .regular : .medium))
    .frame(width: 142, height: 12, alignment: .leading)
}
```

- [ ] **Step 2: Remove the duplicated legend from `DailyActivityPage`**

Keep `ActivityHeatmap` as the sole owner of its grid and footer:

```swift
VStack(alignment: .leading, spacing: 5) {
    ActivityHeatmap(days: snapshot.dailyActivity)
}
.frame(width: 142, alignment: .topLeading)
```

- [ ] **Step 3: Make the running label opaque**

For `.running`, render the status text with a solid orange capsule and keep the outer ticker neutral:

```swift
Text(statusText)
    .font(.system(size: project.state == .running ? 9 : 8, weight: .bold))
    .foregroundStyle(project.state == .running ? Color.black.opacity(0.88) : statusColor)
    .padding(.horizontal, project.state == .running ? 6 : 0)
    .frame(height: project.state == .running ? 17 : nil)
    .background {
        if project.state == .running {
            Capsule().fill(RGBToken.runningAccent.color)
        }
    }

private var statusBackground: Color {
    Color.primary.opacity(0.07)
}

private var statusBorder: Color { .clear }
```

- [ ] **Step 4: Run the complete suite**

Run: `swift test`

Expected: all tests pass with zero failures.

### Task 3: Package and activate the verified app

**Files:**
- Generated: `dist/Codex Monitor.app`

**Interfaces:**
- Consumes: the tested Swift package
- Produces: signed application bundle used by the installed LaunchAgent

- [ ] **Step 1: Package**

Run: `bash scripts/package-app.sh`

Expected: exit code 0 and updated `dist/Codex Monitor.app`.

- [ ] **Step 2: Verify signing**

Run: `codesign --verify --deep --strict --verbose=2 'dist/Codex Monitor.app'`

Expected: “valid on disk” and “satisfies its Designated Requirement”.

- [ ] **Step 3: Restart the login job**

Run `launchctl kickstart -k gui/$(id -u)/com.dafeng.codexmonitor.loginitem`, then inspect the job and process list.

Expected: the LaunchAgent is running the newly packaged executable and only one `CodexMonitor` process remains.

- [ ] **Step 4: Commit implementation**

```bash
git add Sources/CodexMonitor/UI/VisualTokens.swift \
  Sources/CodexMonitor/Notch/ActivityHeatmap.swift \
  Sources/CodexMonitor/Notch/DailyActivityPage.swift \
  Sources/CodexMonitor/MenuBar/MenuBarContentView.swift \
  Tests/CodexMonitorTests/VisualFeedbackTests.swift \
  docs/superpowers/plans/2026-07-14-immediate-heatmap-running-status.md
git commit -m "fix: 提升运行状态与热力格反馈"
```
