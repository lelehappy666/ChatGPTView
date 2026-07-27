# macOS 菜单栏单页下拉面板最终修复报告

日期：2026-07-27

## 结论

本轮审查共处理 5 条 finding：4 条已修复，1 条因性能与视觉验证风险暂缓。设计规范、实施计划和进度账本均未修改。

代码与测试提交：

- `929c2c40590d7d6629d23c9f6235cd930a96303b`（`修复：完善菜单面板边界与辅助功能`）

## Finding 状态

### I1：过期额度伪装成当前额度 — FIXED

- 提取纯 `MenuWeeklyQuotaPresentation`，统一生成剩余额度、已用额度、进度比例和重置时间。
- 新鲜额度保持原有展示。
- 额度过期或缺失时：
  - 剩余额度显示“—”且不显示百分号；
  - 本周已用显示“—”；
  - 进度条仅保留中性底轨，不显示强调色进度；
  - 重置时间显示“—”，不再展示旧倒计时。
- 重置倒计时使用传入的 `now` 计算，展示与新鲜度判断采用同一时间基准。

### M1：无数据与真实零使用无法区分 — FIXED

- `MonitorSnapshot.lastUpdatedAt` 是可靠可用性信号：没有扫描到任何本地会话时为 `nil`；存在真实会话时，即使 Token 为 0，也有更新时间。
- 新增纯 `MenuLocalUsagePresentation`：
  - 无本地数据时，每日活动和统计总览显示紧凑空状态；
  - 已有真实数据但使用量为 0 时，继续显示零值指标。
- 两个模块复用同一紧凑空状态，未扩展数据模型或扫描架构。

### M2：状态栏辅助功能名称错误 — FIXED

- 为 `NSStatusBarButton` 设置辅助功能名称“Codex Monitor”。
- 设置随面板状态变化的辅助功能帮助文本。
- 使用 `setAccessibilityExpanded` 反映面板展开状态。
- 通过 `NSPopoverDelegate` 的实际打开、关闭回调同步状态，覆盖点击外部自动关闭。
- 隐藏 SwiftUI 结绳子图标的独立辅助功能元素，不再朗读为“ChatGPT”。
- 没有稳定的菜单栏 AppKit 自动化入口，本项由代码审查和完整编译覆盖。

### M3：零尺寸屏幕产生负内容尺寸 — FIXED

- `MenuPopoverLayout.contentSize` 的宽高最终值钳制为非负数。
- `.zero` 输入现在返回 `.zero`。
- 正常屏幕目标尺寸和小屏幕扣除安全边距的行为保持不变。

### M4：纯黑背景与半透明材质有偏差 — DEFERRED

- 本轮未修改根视图纯黑背景。
- 直接使用 SwiftUI 材质会引入明显的离屏模糊；改用 `NSVisualEffectView` 又会扩大当前 SwiftUI/`NSPopover` 架构。
- 现有进度账本已记录纯菜单栏辅助应用无法由 Computer Use 附着，无法在本轮进行可靠视觉和性能对比。
- 按 finding 的限制，避免引入未经目测与性能验证的渲染回退，留给用户在真实面板中目测后再决定。

## TDD 记录

### I1

RED：

```text
xcrun swift test --disable-sandbox --filter 'MenuDashboardCompositionTests/testWeeklyQuotaPresentation'
```

新增“新鲜、过期、缺失”3 个展示行为测试后，因 `MenuWeeklyQuotaPresentation` 尚不存在而编译失败，失败原因与待实现纯展示模型一致。

GREEN：

```text
Executed 3 tests, with 0 failures
```

### M1

RED：

```text
xcrun swift test --disable-sandbox --filter 'MenuDashboardCompositionTests/testLocalUsagePresentation'
```

新增“无扫描数据为空状态、真实零使用保留指标”2 个行为测试后，因 `MenuLocalUsagePresentation` 尚不存在而编译失败。

GREEN：

```text
Executed 2 tests, with 0 failures
```

### M3

RED：

```text
xcrun swift test --disable-sandbox --filter 'MenuPopoverLayoutTests/testZeroVisibleFrameDoesNotProduceNegativeContentSize'
```

测试按预期失败：

```text
XCTAssertEqual failed: ("(-24.0, -24.0)") is not equal to ("(0.0, 0.0)")
```

GREEN：

```text
xcrun swift test --disable-sandbox --filter 'MenuPopoverLayoutTests'
Executed 4 tests, with 0 failures
```

## 最终验证

所有命令均显式使用完整 Xcode 工具链：

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
Apple Swift version 6.3.3
```

相关筛选测试：

```text
xcrun swift test --disable-sandbox --filter 'MenuDashboardCompositionTests|MenuPopoverLayoutTests|AppIntegrationTests'
Executed 29 tests, with 0 failures
```

完整测试：

```text
xcrun swift test --disable-sandbox
Executed 113 tests, with 0 failures
```

完整构建：

```text
xcrun swift build --disable-sandbox
Build complete
```

SwiftPM 报告用户级配置和缓存目录不可写，因此禁用了用户级缓存；模块缓存已放入工作区可写目录。该环境警告未造成测试或构建失败。

## 顾虑与后续

- M2 的 VoiceOver 实际朗读与展开状态仍需用户在真实菜单栏中目测/听测；当前由 AppKit API 代码审查、代理回调和完整编译覆盖。
- M4 保持暂缓，避免未经验证的材质模糊造成性能回退；如用户确认必须贴近半透明确认稿，应单独安排真实设备视觉与性能验证。
