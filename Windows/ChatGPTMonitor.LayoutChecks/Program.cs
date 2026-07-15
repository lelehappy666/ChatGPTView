using ChatGPTMonitor;
using System.Drawing;

static void Check(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
}

foreach (var dpi in new[] { 96, 120, 144, 168, 192 })
{
    var metrics = IslandLayout.For(dpi);
    var scale = dpi / 96f;

    Check(metrics.CompactSize.Width == (int)Math.Round(286 * scale), $"{dpi} DPI 收起宽度错误");
    Check(metrics.CompactSize.Height == (int)Math.Round(48 * scale), $"{dpi} DPI 收起高度错误");
    Check(metrics.ExpandedSize.Width == (int)Math.Round(430 * scale), $"{dpi} DPI 展开宽度错误");
    Check(metrics.ExpandedSize.Height == (int)Math.Round(300 * scale), $"{dpi} DPI 展开高度错误");

    var headerItems = new[]
    {
        metrics.LogoBounds,
        metrics.BrandBounds,
        metrics.QuotaBadgeBounds,
        metrics.ProjectBounds
    };
    for (var index = 1; index < headerItems.Length; index++)
    {
        Check(headerItems[index - 1].Right <= headerItems[index].Left, $"{dpi} DPI 标题元素发生重叠");
    }

    Check(metrics.NavigationTabs.Count == 3, $"{dpi} DPI 标签页数量错误");
    Check(metrics.NavigationTabs.All(metrics.ExpandedClientBounds.Contains), $"{dpi} DPI 标签页越界");
    Check(metrics.StatisticsCards.Count == 4, $"{dpi} DPI 统计卡片数量错误");
    Check(metrics.StatisticsCards.All(metrics.PageSafeBounds.Contains), $"{dpi} DPI 统计卡片越过安全区");

    Check(metrics.QuotaRightBounds.Left - metrics.QuotaLeftBounds.Right >= metrics.ScaleLength(18), $"{dpi} DPI 周额度列间距不足");
    Check(metrics.ActivityMetricsBounds.Width >= metrics.ScaleLength(132), $"{dpi} DPI 活动指标宽度不足");
    Check(metrics.ExpandedSize.Height - metrics.StatisticsCards.Max(card => card.Bottom) >= metrics.ScaleLength(16), $"{dpi} DPI 统计卡片底部空间不足");

    for (var page = 0; page < 3; page++)
    {
        var tab = metrics.NavigationTabs[page];
        Check(metrics.TabAt(new Point(tab.Left + tab.Width / 2, tab.Top + tab.Height / 2)) == page, $"{dpi} DPI 标签命中错误");
    }
    Check(metrics.ActivityCellAt(Point.Empty) == -1, $"{dpi} DPI 活动格外部命中错误");
    for (var index = 0; index < 60; index++)
    {
        var cell = metrics.ActivityCell(index);
        var center = new Point(cell.Left + cell.Width / 2, cell.Top + cell.Height / 2);
        Check(metrics.ActivityCellAt(center) == index, $"{dpi} DPI 第 {index + 1} 个活动格命中错误");
    }
}

var hover = new HoverExpansionState();
hover.PointerEntered();
hover.PointerExited();
Check(hover.OpenDelayElapsed() == HoverExpansionAction.None, "短暂经过不应展开");

hover.PointerEntered();
Check(hover.OpenDelayElapsed() == HoverExpansionAction.ExpandAndRefresh, "稳定悬停应展开并刷新");
Check(hover.OpenDelayElapsed() == HoverExpansionAction.None, "重复移动不能重复刷新");

hover.PointerExited();
hover.PointerEntered();
Check(hover.CloseDelayElapsed() == HoverExpansionAction.None, "收起等待期间重新进入不能收起");

hover.PointerExited();
Check(hover.CloseDelayElapsed() == HoverExpansionAction.Collapse, "移开后应收起");
Check(hover.CloseDelayElapsed() == HoverExpansionAction.None, "已经收起时不能重复收起");

Check(hover.ForceExpanded() == HoverExpansionAction.ExpandAndRefresh, "托盘应主动展开并刷新");
Check(hover.ForceExpanded() == HoverExpansionAction.None, "托盘不能重复展开或刷新");

Check(WindowsBackdrop.SystemBackdropTypeForIsland == 1, "Windows 顶部窗口必须关闭矩形系统背景");
Check(WindowsBackdrop.CornerPreferenceForIsland == 1, "Windows 顶部窗口圆角必须完全由 Region 负责");
Check(WindowsBackdrop.BorderColorForIsland == -2, "Windows 顶部窗口必须关闭 DWM 自动边框");

Console.WriteLine("全部布局契约检查通过");
