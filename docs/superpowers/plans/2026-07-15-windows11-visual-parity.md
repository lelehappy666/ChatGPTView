# Windows 11 视觉一致性优化实施计划

> **执行说明：** 必须使用 `superpowers:executing-plans` 按任务实施；每一步使用复选框跟踪。

**目标：** 将 Windows 11 顶部监控器改为统一的 DPI 感知全自绘界面，使收起胶囊和三个展开页面与确认设计稿保持一致。

**架构：** 新增纯布局模型负责所有逻辑坐标和 DPI 换算，并用无第三方依赖的控制台契约检查验证安全边距。`TopIslandForm` 只负责窗口生命周期、动画、命中测试和调用渲染器；`IslandRenderer` 负责绘制背景、文字、图标、标签页与三个页面，避免 WinForms 子控件字体测量造成错位。

**技术栈：** .NET 8、C#、Windows Forms、GDI+、DWM、System.Drawing，不新增第三方 NuGet 依赖。

## 全局约束

- 所有文档与 Git 提交信息使用中文。
- 收起逻辑尺寸为 286×48，展开逻辑尺寸为 430×300。
- 支持 100%、125%、150%、175% 和 200% DPI。
- `ChatGPT`、`Week xx%` 和项目状态始终横向排列。
- 三页数据禁止裁切；无真实额度时显示 `--`。
- 保留现有数据、托盘、开机启动与完成通知行为。
- 最终仍由 `build-win11.bat` 生成 `dist-win11\ChatGPT.exe`。

---

### 任务一：建立 DPI 布局模型与失败契约检查

**文件：**
- 创建：`Windows/ChatGPTMonitor/IslandLayout.cs`
- 创建：`Windows/ChatGPTMonitor.LayoutChecks/ChatGPTMonitor.LayoutChecks.csproj`
- 创建：`Windows/ChatGPTMonitor.LayoutChecks/Program.cs`

**接口：**
- 产生：`IslandLayout.CompactSize`、`IslandLayout.ExpandedSize`、`IslandLayout.For(int dpi)`。
- 产生：`IslandMetrics.Scale(Rectangle)`、标题区、标签区、三个页面安全区域和命中矩形。

- [ ] **步骤 1：先创建契约检查程序**

检查 96、120、144、168、192 DPI 下的物理窗口尺寸；断言标题元素不重叠、标签页不越界、四张统计卡片完全位于页面安全区域。

- [ ] **步骤 2：运行检查并确认失败**

运行：

```bash
dotnet run --project Windows/ChatGPTMonitor.LayoutChecks/ChatGPTMonitor.LayoutChecks.csproj
```

预期：因为 `IslandLayout.cs` 尚不存在而编译失败。

- [ ] **步骤 3：实现最小布局模型**

使用 96 DPI 逻辑坐标和 `dpi / 96f` 比例统一换算：

```csharp
internal sealed class IslandMetrics
{
    public float ScaleFactor { get; }
    public Rectangle Scale(Rectangle value) => new(
        (int)Math.Round(value.X * ScaleFactor),
        (int)Math.Round(value.Y * ScaleFactor),
        (int)Math.Round(value.Width * ScaleFactor),
        (int)Math.Round(value.Height * ScaleFactor));
}
```

- [ ] **步骤 4：重新运行契约检查**

预期输出：`全部布局契约检查通过`。

- [ ] **步骤 5：提交任务一**

```bash
git add Windows/ChatGPTMonitor/IslandLayout.cs Windows/ChatGPTMonitor.LayoutChecks
git commit -m "开发：建立 Windows 自绘布局契约"
```

### 任务二：实现统一的 Windows 11 自绘渲染器

**文件：**
- 创建：`Windows/ChatGPTMonitor/IslandRenderer.cs`
- 修改：`Windows/ChatGPTMonitor/Theme.cs`

**接口：**
- 消费：`IslandMetrics`、`MonitorSnapshot`、当前页索引和悬停活动格索引。
- 产生：`IslandRenderer.Draw(Graphics, IslandRenderState)`。
- 产生：`Theme.CreateEnglishFont(...)`、`Theme.CreateChineseFont(...)`、DPI 像素换算与圆角填充辅助函数。

- [ ] **步骤 1：扩展契约检查以要求三页绘制区域**

新增断言：周额度左右列之间至少保留 18 逻辑像素；活动页右侧指标宽度不少于 132；统计卡片底部距窗口至少 16。

- [ ] **步骤 2：运行检查并确认新断言失败**

预期：缺少对应区域或尺寸不满足时输出明确的中文失败信息。

- [ ] **步骤 3：实现渲染器**

渲染顺序固定为背景材质遮罩、外描边、标题区、标签页、当前页面。文本使用 `TextRenderer.DrawText` 与 `NoPadding | SingleLine | VerticalCenter`；只有项目名允许 `EndEllipsis`。ChatGPT 标志使用六段旋转圆角环形路径绘制，不能再使用字符 `C`。

- [ ] **步骤 4：运行布局检查并构建 Windows 项目**

```bash
dotnet run --project Windows/ChatGPTMonitor.LayoutChecks/ChatGPTMonitor.LayoutChecks.csproj
dotnet build Windows/ChatGPTMonitor/ChatGPTMonitor.csproj -p:EnableWindowsTargeting=true
```

预期：契约检查通过，Windows 项目构建成功。

- [ ] **步骤 5：提交任务二**

```bash
git add Windows/ChatGPTMonitor/IslandRenderer.cs Windows/ChatGPTMonitor/Theme.cs Windows/ChatGPTMonitor/IslandLayout.cs Windows/ChatGPTMonitor.LayoutChecks
git commit -m "开发：实现 Windows 11 全自绘视觉"
```

### 任务三：将顶部窗口切换为全自绘交互

**文件：**
- 重写：`Windows/ChatGPTMonitor/TopIslandForm.cs`
- 删除：`Windows/ChatGPTMonitor/ActivityGridControl.cs`

**接口：**
- 保留：`TopIslandForm.UpdateSnapshot(MonitorSnapshot)`。
- 保留：`TopIslandForm.ToggleExpanded()`。
- 新增：基于 `IslandMetrics` 的标签页、标题区和 60 个活动格命中测试。

- [ ] **步骤 1：新增命中测试契约**

断言三个标签页中心点分别命中页面 0、1、2；活动格外部返回 `-1`；60 个活动格中心依次返回 0 到 59。

- [ ] **步骤 2：运行契约并确认失败**

预期：因为命中接口尚未实现而编译失败。

- [ ] **步骤 3：重写窗口**

窗口设置 `AutoScaleMode.None`，在 `OnDpiChanged` 中重建尺寸与圆角；`OnPaint` 调用渲染器；鼠标点击切换展开或标签页；鼠标移动命中活动格并立即显示 ToolTip；动画保持 180 毫秒三次缓出。

- [ ] **步骤 4：运行契约检查与 Windows 构建**

预期：全部布局与命中检查通过，项目构建成功。

- [ ] **步骤 5：提交任务三**

```bash
git add Windows/ChatGPTMonitor/TopIslandForm.cs Windows/ChatGPTMonitor/ActivityGridControl.cs Windows/ChatGPTMonitor.LayoutChecks
git commit -m "优化：对齐 Windows 顶部监控交互与布局"
```

### 任务四：接入 DWM 材质并完成打包检查

**文件：**
- 创建：`Windows/ChatGPTMonitor/WindowsBackdrop.cs`
- 修改：`Windows/ChatGPTMonitor/TopIslandForm.cs`
- 修改：`Windows/ChatGPTMonitor/ChatGPTMonitor.csproj`
- 修改：`build-win11.bat`
- 修改：`Windows/README.md`

**接口：**
- 产生：`WindowsBackdrop.Apply(nint windowHandle)`，Windows 11 使用深色系统背景材质，不支持时静默回退。
- 构建脚本在发布前执行布局契约检查。

- [ ] **步骤 1：实现 DWM 兼容封装**

使用 `DwmSetWindowAttribute` 设置沉浸式深色模式、圆角偏好和系统背景类型；所有返回值仅用于决定回退，不使应用崩溃。

- [ ] **步骤 2：把契约检查接入 BAT**

在 `dotnet publish` 之前执行：

```bat
"%DOTNET_EXE%" run --project "%~dp0Windows\ChatGPTMonitor.LayoutChecks\ChatGPTMonitor.LayoutChecks.csproj" --configuration Release
if errorlevel 1 goto layout_check_failed
```

- [ ] **步骤 3：更新中文说明**

明确说明全自绘、DPI 支持、无第三方依赖以及真机截图检查项目。

- [ ] **步骤 4：执行完整验证**

```bash
dotnet run --project Windows/ChatGPTMonitor.LayoutChecks/ChatGPTMonitor.LayoutChecks.csproj --configuration Release
dotnet build Windows/ChatGPTMonitor/ChatGPTMonitor.csproj -c Release -p:EnableWindowsTargeting=true
git diff --check
```

预期：契约检查与构建成功，Git 无空白错误。

- [ ] **步骤 5：提交任务四**

```bash
git add Windows/ChatGPTMonitor Windows/ChatGPTMonitor.LayoutChecks build-win11.bat Windows/README.md
git commit -m "优化：完成 Windows 11 视觉一致性打包"
```
