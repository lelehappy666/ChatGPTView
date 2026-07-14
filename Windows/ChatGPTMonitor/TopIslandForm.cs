using System.Drawing.Drawing2D;

namespace ChatGPTMonitor;

internal sealed class TopIslandForm : Form
{
    private static readonly Size CompactSize = new(286, 48);
    private static readonly Size ExpandedSize = new(430, 300);

    private readonly Panel _header;
    private readonly Label _quotaBadge;
    private readonly Label _projectStatus;
    private readonly Panel _content;
    private readonly Panel _quotaPage;
    private readonly Panel _activityPage;
    private readonly Panel _statisticsPage;
    private readonly Label _remainingValue;
    private readonly Label _usedValue;
    private readonly Label _resetValue;
    private readonly Panel _progressFill;
    private readonly ActivityGridControl _activityGrid;
    private readonly Label _todayTokens;
    private readonly Label _todaySessions;
    private readonly Label _averageTokens;
    private readonly Label _streakValue;
    private readonly Label[] _statValues;
    private readonly System.Windows.Forms.Timer _animationTimer;
    private Size _animationStart;
    private Size _animationTarget;
    private int _animationStep;
    private bool _expanded;

    protected override bool ShowWithoutActivation => true;

    protected override CreateParams CreateParams
    {
        get
        {
            const int wsExToolWindow = 0x00000080;
            var parameters = base.CreateParams;
            parameters.ExStyle |= wsExToolWindow;
            return parameters;
        }
    }

    public TopIslandForm()
    {
        Text = "ChatGPT";
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        TopMost = true;
        StartPosition = FormStartPosition.Manual;
        BackColor = Theme.Window;
        ForeColor = Theme.Text;
        DoubleBuffered = true;
        Size = CompactSize;
        MinimumSize = CompactSize;
        MaximumSize = ExpandedSize;

        _header = new Panel
        {
            Location = Point.Empty,
            Size = new Size(ExpandedSize.Width, CompactSize.Height),
            BackColor = Theme.Window,
            Cursor = Cursors.Hand
        };
        var mark = NewLabel("C", 12, FontStyle.Bold, Theme.Window, ContentAlignment.MiddleCenter);
        mark.Location = new Point(12, 11);
        mark.Size = new Size(26, 26);
        mark.BackColor = Color.FromArgb(111, 215, 237);
        Theme.ApplyRoundedRegion(mark, 8);

        var name = NewLabel("ChatGPT", 10.5f, FontStyle.Bold, Theme.Text);
        name.Location = new Point(47, 14);
        name.Size = new Size(62, 22);

        _quotaBadge = NewLabel("Week --%", 9.5f, FontStyle.Bold, Color.FromArgb(228, 220, 255), ContentAlignment.MiddleCenter);
        _quotaBadge.Location = new Point(112, 11);
        _quotaBadge.Size = new Size(74, 26);
        _quotaBadge.BackColor = Color.FromArgb(38, 31, 61);
        Theme.ApplyRoundedRegion(_quotaBadge, 8);

        _projectStatus = NewLabel("● 等待数据", 9, FontStyle.Regular, Theme.Muted, ContentAlignment.MiddleLeft);
        _projectStatus.Location = new Point(194, 12);
        _projectStatus.Size = new Size(86, 24);

        _header.Controls.AddRange(new Control[] { mark, name, _quotaBadge, _projectStatus });
        foreach (Control control in _header.Controls)
            control.Click += (_, _) => ToggleExpanded();
        _header.Click += (_, _) => ToggleExpanded();
        Controls.Add(_header);

        _content = new Panel
        {
            Location = new Point(0, 48),
            Size = new Size(430, 252),
            BackColor = Theme.Window,
            Visible = false
        };
        Controls.Add(_content);

        var navigation = new Panel
        {
            Location = new Point(12, 0),
            Size = new Size(406, 38),
            BackColor = Theme.Window
        };
        var quotaButton = NewTabButton("周额度", 0);
        var activityButton = NewTabButton("每日活动", 86);
        var statsButton = NewTabButton("统计总览", 184);
        navigation.Controls.AddRange(new Control[] { quotaButton, activityButton, statsButton });
        _content.Controls.Add(navigation);

        _quotaPage = NewPage();
        _activityPage = NewPage();
        _statisticsPage = NewPage();
        _content.Controls.AddRange(new Control[] { _quotaPage, _activityPage, _statisticsPage });

        quotaButton.Click += (_, _) => ShowPage(_quotaPage, quotaButton, navigation);
        activityButton.Click += (_, _) => ShowPage(_activityPage, activityButton, navigation);
        statsButton.Click += (_, _) => ShowPage(_statisticsPage, statsButton, navigation);

        _remainingValue = NewLabel("--%", 30, FontStyle.Bold, Theme.Text);
        _remainingValue.Location = new Point(18, 45);
        _remainingValue.Size = new Size(120, 55);
        var remainingTitle = NewLabel("剩余周额度", 9, FontStyle.Regular, Theme.Muted);
        remainingTitle.Location = new Point(18, 22);
        remainingTitle.Size = new Size(100, 20);
        var divider = new Panel { Location = new Point(151, 20), Size = new Size(1, 142), BackColor = Theme.Border };
        var usedTitle = NewLabel("本周已用", 9, FontStyle.Regular, Theme.Muted);
        usedTitle.Location = new Point(174, 25);
        usedTitle.Size = new Size(88, 20);
        _usedValue = NewLabel("--%", 10, FontStyle.Bold, Theme.Text, ContentAlignment.MiddleRight);
        _usedValue.Location = new Point(310, 25);
        _usedValue.Size = new Size(86, 20);
        var progressTrack = new Panel { Location = new Point(174, 56), Size = new Size(222, 8), BackColor = Color.FromArgb(43, 46, 56) };
        Theme.ApplyRoundedRegion(progressTrack, 4);
        _progressFill = new Panel { Dock = DockStyle.Left, Width = 0, BackColor = Theme.Purple };
        progressTrack.Controls.Add(_progressFill);
        var resetTitle = NewLabel("距离重置", 9, FontStyle.Regular, Theme.Muted);
        resetTitle.Location = new Point(174, 86);
        resetTitle.Size = new Size(80, 20);
        _resetValue = NewLabel("--", 10, FontStyle.Bold, Theme.Text, ContentAlignment.MiddleRight);
        _resetValue.Location = new Point(270, 86);
        _resetValue.Size = new Size(126, 20);
        var synced = NewLabel("● 数据已同步", 9, FontStyle.Regular, Theme.Green);
        synced.Location = new Point(174, 125);
        synced.Size = new Size(130, 20);
        _quotaPage.Controls.AddRange(new Control[]
        {
            remainingTitle, _remainingValue, divider, usedTitle, _usedValue,
            progressTrack, resetTitle, _resetValue, synced
        });

        var activityTitle = NewLabel("最近 60 天 · 每格代表一天", 9, FontStyle.Regular, Theme.Muted);
        activityTitle.Location = new Point(14, 10);
        activityTitle.Size = new Size(220, 20);
        _activityGrid = new ActivityGridControl { Location = new Point(14, 39), Size = new Size(236, 112) };
        var activityDivider = new Panel { Location = new Point(265, 12), Size = new Size(1, 158), BackColor = Theme.Border };
        var todayTitle = NewLabel("今天", 9, FontStyle.Regular, Theme.Muted);
        todayTitle.Location = new Point(283, 10);
        todayTitle.Size = new Size(80, 20);
        _todayTokens = NewLabel("0", 24, FontStyle.Bold, Theme.Text);
        _todayTokens.Location = new Point(283, 31);
        _todayTokens.Size = new Size(125, 42);
        _todaySessions = NewMetricLine("会话", 78);
        _averageTokens = NewMetricLine("平均/天", 105);
        _streakValue = NewMetricLine("连续使用", 132);
        _activityPage.Controls.AddRange(new Control[]
        {
            activityTitle, _activityGrid, activityDivider, todayTitle, _todayTokens,
            _todaySessions, _averageTokens, _streakValue
        });

        var statLabels = new[] { "累计 Token 数", "峰值 Token 数", "最长任务时长", "当前 / 最长连续" };
        _statValues = new Label[4];
        for (var index = 0; index < statLabels.Length; index++)
        {
            var x = index % 2 == 0 ? 12 : 218;
            var y = index < 2 ? 8 : 101;
            var card = NewStatCard(statLabels[index], x, y, out var value);
            _statValues[index] = value;
            _statisticsPage.Controls.Add(card);
        }

        ShowPage(_quotaPage, quotaButton, navigation);
        _animationTimer = new System.Windows.Forms.Timer { Interval = 15 };
        _animationTimer.Tick += AnimateWindow;
        Resize += (_, _) => Theme.ApplyRoundedRegion(this, _expanded ? 22 : 24);
        Shown += (_, _) => PositionAtTop();
    }

    public void ToggleExpanded()
    {
        _expanded = !_expanded;
        _animationStart = Size;
        _animationTarget = _expanded ? ExpandedSize : CompactSize;
        _animationStep = 0;
        if (_expanded) _content.Visible = true;
        _animationTimer.Start();
    }

    public void UpdateSnapshot(MonitorSnapshot snapshot)
    {
        var remaining = snapshot.WeeklyQuota.RemainingPercent;
        _quotaBadge.Text = remaining.HasValue ? $"Week {remaining.Value:0}%" : "Week --%";
        _remainingValue.Text = remaining.HasValue ? $"{remaining.Value:0}%" : "--%";
        var used = remaining.HasValue ? 100 - remaining.Value : 0;
        _usedValue.Text = remaining.HasValue ? $"{used:0}%" : "--%";
        _progressFill.Width = (int)Math.Round(222 * used / 100);
        _resetValue.Text = ResetText(snapshot.WeeklyQuota.ResetsAt);

        var project = snapshot.Projects.FirstOrDefault();
        if (project is null)
        {
            _projectStatus.Text = "● 暂无任务";
            _projectStatus.ForeColor = Theme.Muted;
        }
        else
        {
            _projectStatus.Text = project.State switch
            {
                SessionState.Running => $"● {TrimProject(project.Name)}",
                SessionState.Failed => $"● {TrimProject(project.Name)}",
                _ => $"● {TrimProject(project.Name)}"
            };
            _projectStatus.ForeColor = project.State switch
            {
                SessionState.Running => Theme.Orange,
                SessionState.Failed => Theme.Red,
                _ => Theme.Green
            };
        }

        var sixtyDaysAgo = DateTime.Today.AddDays(-59);
        _activityGrid.Days = snapshot.DailyActivity.Where(day => day.Date >= sixtyDaysAgo).ToArray();
        var today = snapshot.DailyActivity.FirstOrDefault(day => day.Date == DateTime.Today);
        _todayTokens.Text = FormatTokens(today?.Tokens ?? 0);
        _todaySessions.Text = $"会话    {today?.Sessions ?? 0}";
        var activeDays = snapshot.DailyActivity.Count(day => day.Tokens > 0);
        var average = activeDays == 0 ? 0 : snapshot.DailyActivity.Sum(day => day.Tokens) / activeDays;
        _averageTokens.Text = $"平均/天    {FormatTokens(average)}";
        _streakValue.Text = $"连续使用    {snapshot.CurrentStreakDays} 天";

        _statValues[0].Text = FormatTokens(snapshot.LifetimeTokens);
        _statValues[1].Text = FormatTokens(snapshot.PeakTokens);
        _statValues[2].Text = FormatDuration(snapshot.LongestTaskDuration);
        _statValues[3].Text = $"{snapshot.CurrentStreakDays} 天 / {snapshot.LongestStreakDays} 天";
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        using var pen = new Pen(Theme.Border, 1);
        using var path = Theme.RoundedRectangle(new Rectangle(0, 0, Width - 1, Height - 1), _expanded ? 22 : 24);
        e.Graphics.DrawPath(pen, path);
    }

    private void AnimateWindow(object? sender, EventArgs e)
    {
        const int totalSteps = 12;
        _animationStep++;
        var progress = Math.Min(1d, _animationStep / (double)totalSteps);
        var eased = 1 - Math.Pow(1 - progress, 3);
        Size = new Size(
            (int)Math.Round(_animationStart.Width + (_animationTarget.Width - _animationStart.Width) * eased),
            (int)Math.Round(_animationStart.Height + (_animationTarget.Height - _animationStart.Height) * eased));
        PositionAtTop();
        if (_animationStep < totalSteps) return;
        _animationTimer.Stop();
        Size = _animationTarget;
        if (!_expanded) _content.Visible = false;
    }

    private void PositionAtTop()
    {
        var area = Screen.FromPoint(Cursor.Position).WorkingArea;
        Location = new Point(area.Left + (area.Width - Width) / 2, area.Top + 8);
    }

    private static Panel NewPage() => new()
    {
        Location = new Point(0, 39),
        Size = new Size(430, 213),
        BackColor = Theme.Window,
        Visible = false
    };

    private static Button NewTabButton(string text, int x) => new()
    {
        Text = text,
        Location = new Point(x, 4),
        Size = new Size(82, 28),
        FlatStyle = FlatStyle.Flat,
        BackColor = Theme.Window,
        ForeColor = Theme.Muted,
        Font = Theme.Font(9),
        Cursor = Cursors.Hand,
        TabStop = false
    };

    private static void ShowPage(Panel page, Button selected, Panel navigation)
    {
        foreach (var sibling in page.Parent?.Controls.OfType<Panel>() ?? Enumerable.Empty<Panel>())
        {
            if (sibling != navigation) sibling.Visible = sibling == page;
        }
        foreach (var button in navigation.Controls.OfType<Button>())
        {
            button.BackColor = button == selected ? Theme.SurfaceRaised : Theme.Window;
            button.ForeColor = button == selected ? Theme.Text : Theme.Muted;
            button.FlatAppearance.BorderSize = 0;
        }
    }

    private static Label NewLabel(
        string text,
        float size,
        FontStyle style,
        Color color,
        ContentAlignment alignment = ContentAlignment.MiddleLeft) => new()
    {
        Text = text,
        Font = Theme.Font(size, style),
        ForeColor = color,
        BackColor = Theme.Window,
        TextAlign = alignment,
        AutoEllipsis = true
    };

    private static Label NewMetricLine(string title, int y)
    {
        var label = NewLabel($"{title}    --", 9, FontStyle.Regular, Theme.Muted);
        label.Location = new Point(283, y);
        label.Size = new Size(127, 22);
        return label;
    }

    private static Panel NewStatCard(string title, int x, int y, out Label value)
    {
        var card = new Panel
        {
            Location = new Point(x, y),
            Size = new Size(194, 82),
            BackColor = Theme.Surface
        };
        Theme.ApplyRoundedRegion(card, 12);
        var titleLabel = NewLabel(title, 8.5f, FontStyle.Regular, Theme.Muted);
        titleLabel.BackColor = Theme.Surface;
        titleLabel.Location = new Point(12, 8);
        titleLabel.Size = new Size(170, 20);
        value = NewLabel("--", 16, FontStyle.Bold, Theme.Text);
        value.BackColor = Theme.Surface;
        value.Location = new Point(12, 31);
        value.Size = new Size(170, 36);
        value.AutoEllipsis = false;
        card.Controls.AddRange(new Control[] { titleLabel, value });
        return card;
    }

    private static string TrimProject(string value) => value.Length > 8 ? value[..7] + "…" : value;

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
        if (duration.TotalHours >= 1)
            return $"{(int)duration.TotalHours} 小时 {duration.Minutes} 分";
        if (duration.TotalMinutes >= 1)
            return $"{(int)duration.TotalMinutes} 分 {duration.Seconds} 秒";
        return $"{Math.Max(0, duration.Seconds)} 秒";
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) _animationTimer.Dispose();
        base.Dispose(disposing);
    }
}
