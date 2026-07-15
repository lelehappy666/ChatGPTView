using System.Drawing.Drawing2D;
using System.Drawing.Text;

namespace ChatGPTMonitor;

internal enum IslandPage
{
    Quota,
    Activity,
    Statistics
}

internal sealed record IslandRenderState(
    MonitorSnapshot Snapshot,
    IslandMetrics Metrics,
    bool Expanded,
    IslandPage Page,
    int HoveredActivityCell);

internal sealed class IslandRenderer
{
    private static readonly TextFormatFlags BaseTextFlags =
        TextFormatFlags.NoPadding |
        TextFormatFlags.SingleLine |
        TextFormatFlags.VerticalCenter |
        TextFormatFlags.PreserveGraphicsClipping;

    public void Draw(Graphics graphics, IslandRenderState state)
    {
        graphics.SmoothingMode = SmoothingMode.AntiAlias;
        graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
        graphics.CompositingQuality = CompositingQuality.HighQuality;
        graphics.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;

        DrawWindowBackground(graphics, state);
        DrawHeader(graphics, state);
        if (!state.Expanded) return;

        DrawNavigation(graphics, state);
        switch (state.Page)
        {
            case IslandPage.Activity:
                DrawActivityPage(graphics, state);
                break;
            case IslandPage.Statistics:
                DrawStatisticsPage(graphics, state);
                break;
            default:
                DrawQuotaPage(graphics, state);
                break;
        }
    }

    private static void DrawWindowBackground(Graphics graphics, IslandRenderState state)
    {
        var bounds = state.Expanded
            ? new Rectangle(Point.Empty, state.Metrics.ExpandedSize)
            : new Rectangle(Point.Empty, state.Metrics.CompactSize);
        bounds.Width -= 1;
        bounds.Height -= 1;
        var radius = state.Metrics.ScaleLength(state.Expanded ? 22 : 24);
        using var path = Theme.RoundedRectangle(bounds, radius);
        using var background = new SolidBrush(Color.FromArgb(246, Theme.Window));
        using var border = new Pen(Color.FromArgb(190, Theme.Border), Math.Max(1, state.Metrics.ScaleLength(1)));
        graphics.FillPath(background, path);
        graphics.DrawPath(border, path);
    }

    private static void DrawHeader(Graphics graphics, IslandRenderState state)
    {
        var metrics = state.Metrics;
        DrawChatGptMark(graphics, metrics.LogoBounds, metrics.ScaleFactor);

        using var brandFont = Theme.CreateEnglishFont(metrics.ScaleLength(14), FontStyle.Bold);
        DrawText(graphics, "ChatGPT", brandFont, Theme.Text, metrics.BrandBounds);

        FillRounded(graphics, metrics.QuotaBadgeBounds, Theme.SurfaceRaised, metrics.ScaleLength(9));
        using var quotaFont = Theme.CreateEnglishFont(metrics.ScaleLength(12), FontStyle.Bold);
        var remaining = state.Snapshot.WeeklyQuota.RemainingPercent;
        var quota = remaining.HasValue ? $"Week {remaining.Value:0}%" : "Week --%";
        DrawText(
            graphics,
            quota,
            quotaFont,
            Color.FromArgb(232, 224, 255),
            metrics.QuotaBadgeBounds,
            TextFormatFlags.HorizontalCenter);

        var projectBounds = state.Expanded ? metrics.ExpandedProjectBounds : metrics.ProjectBounds;
        var project = state.Snapshot.Projects.FirstOrDefault();
        var projectColor = project?.State switch
        {
            SessionState.Running => Theme.Orange,
            SessionState.Failed => Theme.Red,
            SessionState.Completed => Theme.Green,
            _ => Theme.Muted
        };
        var projectName = project?.Name ?? "暂无任务";
        var dotSize = Math.Max(6, metrics.ScaleLength(7));
        var dot = new Rectangle(
            projectBounds.Left,
            projectBounds.Top + (projectBounds.Height - dotSize) / 2,
            dotSize,
            dotSize);
        using (var dotBrush = new SolidBrush(projectColor))
        {
            graphics.FillEllipse(dotBrush, dot);
        }
        var textBounds = new Rectangle(
            dot.Right + metrics.ScaleLength(7),
            projectBounds.Top,
            Math.Max(0, projectBounds.Right - dot.Right - metrics.ScaleLength(7)),
            projectBounds.Height);
        using var projectFont = Theme.CreateChineseFont(metrics.ScaleLength(12));
        DrawText(graphics, projectName, projectFont, projectColor, textBounds, TextFormatFlags.EndEllipsis);
    }

    private static void DrawNavigation(Graphics graphics, IslandRenderState state)
    {
        var titles = new[] { "周额度", "每日活动", "统计总览" };
        using var font = Theme.CreateChineseFont(state.Metrics.ScaleLength(13), FontStyle.Regular);
        for (var index = 0; index < titles.Length; index++)
        {
            var selected = index == (int)state.Page;
            var bounds = state.Metrics.NavigationTabs[index];
            if (selected)
            {
                FillRounded(graphics, bounds, Theme.SurfaceRaised, state.Metrics.ScaleLength(8));
            }
            DrawText(
                graphics,
                titles[index],
                font,
                selected ? Theme.Text : Theme.Muted,
                bounds,
                TextFormatFlags.HorizontalCenter);
        }
    }

    private static void DrawQuotaPage(Graphics graphics, IslandRenderState state)
    {
        var metrics = state.Metrics;
        var remaining = state.Snapshot.WeeklyQuota.RemainingPercent;
        var used = remaining.HasValue ? Math.Clamp(100 - remaining.Value, 0, 100) : (double?)null;

        using var labelFont = Theme.CreateChineseFont(metrics.ScaleLength(12));
        using var valueFont = Theme.CreateEnglishFont(metrics.ScaleLength(40), FontStyle.Bold);
        using var smallValueFont = Theme.CreateEnglishFont(metrics.ScaleLength(14), FontStyle.Bold);
        DrawText(graphics, "剩余周额度", labelFont, Theme.Muted, metrics.Scale(new Rectangle(18, 108, 124, 24)));
        DrawText(
            graphics,
            remaining.HasValue ? $"{remaining.Value:0}%" : "--",
            valueFont,
            Theme.Text,
            metrics.Scale(new Rectangle(18, 134, 124, 58)));

        using (var divider = new Pen(Theme.Border, Math.Max(1, metrics.ScaleLength(1))))
        {
            graphics.DrawLine(
                divider,
                metrics.Scale(new Point(151, 108)),
                metrics.Scale(new Point(151, 258)));
        }

        DrawText(graphics, "本周已用", labelFont, Theme.Muted, metrics.Scale(new Rectangle(174, 108, 100, 24)));
        DrawText(
            graphics,
            used.HasValue ? $"{used.Value:0}%" : "--",
            smallValueFont,
            Theme.Text,
            metrics.Scale(new Rectangle(304, 108, 108, 24)),
            TextFormatFlags.Right);

        var track = metrics.Scale(new Rectangle(174, 140, 238, 8));
        FillRounded(graphics, track, Color.FromArgb(43, 46, 56), metrics.ScaleLength(4));
        if (used is > 0)
        {
            var fill = track;
            fill.Width = Math.Max(metrics.ScaleLength(8), (int)Math.Round(track.Width * used.Value / 100));
            FillRounded(graphics, fill, Theme.Purple, metrics.ScaleLength(4));
        }

        DrawText(graphics, "距离重置", labelFont, Theme.Muted, metrics.Scale(new Rectangle(174, 166, 100, 24)));
        DrawText(
            graphics,
            ResetText(state.Snapshot.WeeklyQuota.ResetsAt),
            smallValueFont,
            Theme.Text,
            metrics.Scale(new Rectangle(274, 166, 138, 24)),
            TextFormatFlags.Right);

        var syncBounds = metrics.Scale(new Rectangle(174, 207, 160, 24));
        var dotSize = metrics.ScaleLength(8);
        using (var brush = new SolidBrush(Theme.Green))
        {
            graphics.FillEllipse(brush, syncBounds.Left, syncBounds.Top + (syncBounds.Height - dotSize) / 2, dotSize, dotSize);
        }
        syncBounds.X += dotSize + metrics.ScaleLength(8);
        syncBounds.Width -= dotSize + metrics.ScaleLength(8);
        DrawText(graphics, "数据已同步", labelFont, Theme.Green, syncBounds);
    }

    private static void DrawActivityPage(Graphics graphics, IslandRenderState state)
    {
        var metrics = state.Metrics;
        using var labelFont = Theme.CreateChineseFont(metrics.ScaleLength(11));
        using var metricFont = Theme.CreateChineseFont(metrics.ScaleLength(12));
        using var todayFont = Theme.CreateEnglishFont(metrics.ScaleLength(28), FontStyle.Bold);
        DrawText(
            graphics,
            "最近 60 天 · 每格代表一天",
            labelFont,
            Theme.Muted,
            metrics.Scale(new Rectangle(18, 98, 224, 22)));

        var cells = BuildActivityCells(state.Snapshot.DailyActivity);
        var maxTokens = Math.Max(1L, cells.Max(day => day?.Tokens ?? 0));
        for (var index = 0; index < cells.Count; index++)
        {
            var day = cells[index];
            var level = day is null || day.Tokens <= 0
                ? 0
                : Math.Clamp((int)Math.Ceiling(day.Tokens / (double)maxTokens * 4), 1, 4);
            var color = level switch
            {
                1 => Color.FromArgb(72, 67, 91),
                2 => Color.FromArgb(105, 91, 143),
                3 => Color.FromArgb(145, 121, 204),
                4 => Theme.Purple,
                _ => Color.FromArgb(40, 43, 53)
            };
            var cell = metrics.ActivityCell(index);
            FillRounded(graphics, cell, color, metrics.ScaleLength(3));
            if (state.HoveredActivityCell == index)
            {
                using var outline = new Pen(Theme.Text, Math.Max(1, metrics.ScaleLength(2)));
                using var path = Theme.RoundedRectangle(cell, metrics.ScaleLength(3));
                graphics.DrawPath(outline, path);
            }
        }

        using (var divider = new Pen(Theme.Border, Math.Max(1, metrics.ScaleLength(1))))
        {
            graphics.DrawLine(divider, metrics.Scale(new Point(254, 108)), metrics.Scale(new Point(254, 258)));
        }

        var today = state.Snapshot.DailyActivity.FirstOrDefault(day => day.Date.Date == DateTime.Today);
        DrawText(graphics, "今天", labelFont, Theme.Muted, metrics.Scale(new Rectangle(268, 104, 144, 22)));
        DrawText(graphics, FormatTokens(today?.Tokens ?? 0), todayFont, Theme.Text, metrics.Scale(new Rectangle(268, 126, 144, 42)));

        var activeDays = state.Snapshot.DailyActivity.Count(day => day.Tokens > 0);
        var average = activeDays == 0 ? 0 : state.Snapshot.DailyActivity.Sum(day => day.Tokens) / activeDays;
        DrawMetricLine(graphics, metrics, metricFont, "会话", (today?.Sessions ?? 0).ToString(), 176);
        DrawMetricLine(graphics, metrics, metricFont, "平均/天", FormatTokens(average), 202);
        DrawMetricLine(graphics, metrics, metricFont, "连续使用", $"{state.Snapshot.CurrentStreakDays} 天", 228);
    }

    private static void DrawStatisticsPage(Graphics graphics, IslandRenderState state)
    {
        var labels = new[] { "累计 Token 数", "峰值 Token 数", "最长任务时长", "当前 / 最长连续" };
        var values = new[]
        {
            FormatTokens(state.Snapshot.LifetimeTokens),
            FormatTokens(state.Snapshot.PeakTokens),
            FormatDuration(state.Snapshot.LongestTaskDuration),
            $"{state.Snapshot.CurrentStreakDays} 天 / {state.Snapshot.LongestStreakDays} 天"
        };
        using var labelFont = Theme.CreateChineseFont(state.Metrics.ScaleLength(11));
        using var valueFont = Theme.CreateChineseFont(state.Metrics.ScaleLength(18), FontStyle.Bold);
        for (var index = 0; index < state.Metrics.StatisticsCards.Count; index++)
        {
            var card = state.Metrics.StatisticsCards[index];
            FillRounded(graphics, card, Theme.Surface, state.Metrics.ScaleLength(12));
            using (var border = new Pen(Color.FromArgb(140, Theme.Border), Math.Max(1, state.Metrics.ScaleLength(1))))
            using (var path = Theme.RoundedRectangle(card, state.Metrics.ScaleLength(12)))
            {
                graphics.DrawPath(border, path);
            }
            var padding = state.Metrics.ScaleLength(13);
            var labelBounds = new Rectangle(card.Left + padding, card.Top + state.Metrics.ScaleLength(7), card.Width - padding * 2, state.Metrics.ScaleLength(22));
            var valueBounds = new Rectangle(card.Left + padding, card.Top + state.Metrics.ScaleLength(31), card.Width - padding * 2, state.Metrics.ScaleLength(34));
            DrawText(graphics, labels[index], labelFont, Theme.Muted, labelBounds);
            DrawText(graphics, values[index], valueFont, Theme.Text, valueBounds);
        }
    }

    private static void DrawMetricLine(Graphics graphics, IslandMetrics metrics, Font font, string title, string value, int logicalY)
    {
        DrawText(graphics, title, font, Theme.Muted, metrics.Scale(new Rectangle(268, logicalY, 72, 22)));
        DrawText(graphics, value, font, Theme.Text, metrics.Scale(new Rectangle(334, logicalY, 78, 22)), TextFormatFlags.Right);
    }

    private static void DrawChatGptMark(Graphics graphics, Rectangle bounds, float scale)
    {
        using var gradient = new LinearGradientBrush(bounds, Color.FromArgb(92, 220, 230), Color.FromArgb(169, 138, 245), 45f);
        graphics.FillEllipse(gradient, bounds);

        var center = new PointF(bounds.Left + bounds.Width / 2f, bounds.Top + bounds.Height / 2f);
        using var pen = new Pen(Theme.Window, Math.Max(1.5f, 1.8f * scale))
        {
            StartCap = LineCap.Round,
            EndCap = LineCap.Round,
            LineJoin = LineJoin.Round
        };
        var state = graphics.Save();
        graphics.TranslateTransform(center.X, center.Y);
        for (var index = 0; index < 6; index++)
        {
            graphics.RotateTransform(60);
            var loop = new RectangleF(-2.5f * scale, -8f * scale, 9f * scale, 9f * scale);
            graphics.DrawArc(pen, loop, 205, 250);
        }
        graphics.Restore(state);
    }

    private static void DrawText(
        Graphics graphics,
        string text,
        Font font,
        Color color,
        Rectangle bounds,
        TextFormatFlags extraFlags = 0)
    {
        TextRenderer.DrawText(graphics, text, font, bounds, color, BaseTextFlags | extraFlags);
    }

    private static void FillRounded(Graphics graphics, Rectangle bounds, Color color, int radius)
    {
        using var brush = new SolidBrush(color);
        using var path = Theme.RoundedRectangle(bounds, Math.Max(1, radius));
        graphics.FillPath(brush, path);
    }

    private static IReadOnlyList<UsageDay?> BuildActivityCells(IReadOnlyList<UsageDay> days)
    {
        var byDate = days.ToDictionary(day => day.Date.Date);
        var start = DateTime.Today.AddDays(-59);
        return Enumerable.Range(0, 60)
            .Select(offset => byDate.GetValueOrDefault(start.AddDays(offset)))
            .ToArray();
    }

    private static string ResetText(DateTime? reset)
    {
        if (!reset.HasValue) return "--";
        var remaining = reset.Value - DateTime.Now;
        if (remaining <= TimeSpan.Zero) return "即将刷新";
        return $"{Math.Max(0, remaining.Days)} 天 {remaining.Hours} 小时";
    }

    private static string FormatTokens(long value) => value switch
    {
        >= 100_000_000 => $"{value / 100_000_000d:0.#} 亿",
        >= 10_000 => $"{value / 10_000d:0.#} 万",
        >= 1_000 => $"{value / 1_000d:0.#}K",
        _ => value.ToString("N0")
    };

    private static string FormatDuration(TimeSpan duration)
    {
        if (duration.TotalHours >= 1) return $"{(int)duration.TotalHours} 小时 {duration.Minutes} 分";
        if (duration.TotalMinutes >= 1) return $"{(int)duration.TotalMinutes} 分 {duration.Seconds} 秒";
        return $"{Math.Max(0, duration.Seconds)} 秒";
    }
}
