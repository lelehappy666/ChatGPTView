using System.Drawing.Drawing2D;

namespace ChatGPTMonitor;

internal sealed class TopIslandForm : Form
{
    private const int AnimationSteps = 12;

    private readonly IslandRenderer _renderer = new();
    private readonly Action _requestRefresh;
    private readonly HoverExpansionState _hoverState = new();
    private readonly ToolTip _activityToolTip = new()
    {
        InitialDelay = 0,
        ReshowDelay = 0,
        AutoPopDelay = 10_000,
        ShowAlways = true,
        UseAnimation = true,
        UseFading = true
    };
    private readonly ToolTip _projectToolTip = new()
    {
        InitialDelay = 0,
        ReshowDelay = 0,
        AutoPopDelay = 10_000,
        ShowAlways = true,
        UseAnimation = true,
        UseFading = true
    };
    private readonly System.Windows.Forms.Timer _animationTimer;
    private readonly System.Windows.Forms.Timer _openTimer;
    private readonly System.Windows.Forms.Timer _closeTimer;

    private MonitorSnapshot _snapshot = MonitorSnapshot.Empty;
    private IslandMetrics _metrics;
    private IslandPage _page = IslandPage.Quota;
    private ProjectAnalyticsRange _projectRange = ProjectAnalyticsRange.SevenDays;
    private int _hoveredActivityCell = -1;
    private int _hoveredProjectRow = -1;
    private Size _animationStart;
    private Size _animationTarget;
    private int _animationStep;
    private bool _expanded;
    private bool _renderExpanded;

    protected override bool ShowWithoutActivation => true;

    protected override CreateParams CreateParams
    {
        get
        {
            const int wsExToolWindow = 0x00000080;
            const int wsExNoActivate = 0x08000000;
            var parameters = base.CreateParams;
            parameters.ExStyle |= wsExToolWindow | wsExNoActivate;
            return parameters;
        }
    }

    public TopIslandForm(Action requestRefresh)
    {
        _requestRefresh = requestRefresh;
        Text = "ChatGPT";
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        TopMost = true;
        StartPosition = FormStartPosition.Manual;
        AutoScaleMode = AutoScaleMode.None;
        BackColor = Theme.Window;
        ForeColor = Theme.Text;
        DoubleBuffered = true;
        KeyPreview = false;

        SetStyle(
            ControlStyles.AllPaintingInWmPaint |
            ControlStyles.OptimizedDoubleBuffer |
            ControlStyles.UserPaint |
            ControlStyles.ResizeRedraw,
            true);

        _metrics = IslandLayout.For(DeviceDpi);
        ClientSize = _metrics.CompactSize;
        _animationTimer = new System.Windows.Forms.Timer { Interval = 15 };
        _animationTimer.Tick += AnimateWindow;
        _openTimer = new System.Windows.Forms.Timer { Interval = 80 };
        _openTimer.Tick += (_, _) =>
        {
            _openTimer.Stop();
            ApplyHoverAction(_hoverState.OpenDelayElapsed());
        };
        _closeTimer = new System.Windows.Forms.Timer { Interval = 180 };
        _closeTimer.Tick += (_, _) =>
        {
            _closeTimer.Stop();
            ApplyHoverAction(_hoverState.CloseDelayElapsed());
        };

        Shown += (_, _) =>
        {
            RebuildMetrics(DeviceDpi);
            PositionAtTop();
        };
    }

    public void ShowExpanded()
    {
        ApplyHoverAction(_hoverState.ForceExpanded());
    }

    private void BeginExpansion(bool expanded)
    {
        _expanded = expanded;
        if (expanded) _renderExpanded = true;
        _animationStart = ClientSize;
        _animationTarget = expanded ? _metrics.ExpandedSize : _metrics.CompactSize;
        _animationStep = 0;
        _animationTimer.Start();
        Invalidate();
    }

    private void ApplyHoverAction(HoverExpansionAction action)
    {
        switch (action)
        {
            case HoverExpansionAction.ExpandAndRefresh:
                BeginExpansion(true);
                _requestRefresh();
                break;
            case HoverExpansionAction.Collapse:
                BeginExpansion(false);
                break;
        }
    }

    public void UpdateSnapshot(MonitorSnapshot snapshot)
    {
        _snapshot = snapshot;
        Invalidate();
    }

    protected override void OnPaintBackground(PaintEventArgs e)
    {
        e.Graphics.Clear(Theme.Window);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        _renderer.Draw(
            e.Graphics,
            new IslandRenderState(
                _snapshot,
                _metrics,
                _renderExpanded,
                _page,
                _hoveredActivityCell,
                _projectRange,
                _hoveredProjectRow));
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        base.OnMouseDown(e);
        if (e.Button != MouseButtons.Left) return;

        var page = _metrics.TabAt(e.Location);
        if (page >= 0)
        {
            _page = (IslandPage)page;
            _hoveredActivityCell = -1;
            _hoveredProjectRow = -1;
            _activityToolTip.Hide(this);
            _projectToolTip.Hide(this);
            Invalidate();
            return;
        }

        if (_expanded && _page == IslandPage.ProjectAnalytics)
        {
            var range = _metrics.ProjectRangeAt(e.Location);
            if (range >= 0 && range != (int)_projectRange)
            {
                _projectRange = (ProjectAnalyticsRange)range;
                _hoveredProjectRow = -1;
                _projectToolTip.Hide(this);
                Invalidate();
            }
        }
    }

    protected override void OnMouseEnter(EventArgs e)
    {
        base.OnMouseEnter(e);
        _hoverState.PointerEntered();
        _closeTimer.Stop();
        if (!_hoverState.IsExpanded)
        {
            _openTimer.Stop();
            _openTimer.Start();
        }
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        var nextActivity = _expanded && _page == IslandPage.Activity
            ? _metrics.ActivityCellAt(e.Location)
            : -1;
        var period = _snapshot.ProjectAnalytics.For(_projectRange);
        var nextProject = _expanded && _page == IslandPage.ProjectAnalytics
            ? _metrics.ProjectRowAt(e.Location)
            : -1;
        if (nextProject >= period.Rows.Count) nextProject = -1;
        if (nextActivity == _hoveredActivityCell &&
            nextProject == _hoveredProjectRow)
        {
            return;
        }

        _hoveredActivityCell = nextActivity;
        _hoveredProjectRow = nextProject;
        _activityToolTip.Hide(this);
        _projectToolTip.Hide(this);
        if (nextActivity >= 0)
        {
            var date = DateTime.Today.AddDays(-59 + nextActivity);
            var day = _snapshot.DailyActivity.FirstOrDefault(item => item.Date.Date == date);
            var text = day is null
                ? $"{date:yyyy年M月d日}\n无活动"
                : $"{date:yyyy年M月d日}\n{FormatTokens(day.Tokens)} Token · {day.Sessions} 个会话";
            _activityToolTip.Show(
                text,
                this,
                e.X + _metrics.ScaleLength(12),
                e.Y + _metrics.ScaleLength(16),
                10_000);
        }
        else if (nextProject >= 0)
        {
            var row = period.Rows[nextProject];
            var average = row.Sessions > 0 ? row.Tokens / row.Sessions : 0;
            _projectToolTip.Show(
                $"{row.Name}\n{row.Sessions} 次会话 · {row.ActiveDays} 个活跃日 · 平均 {FormatTokens(average)} Token/会话",
                this,
                e.X + _metrics.ScaleLength(12),
                e.Y + _metrics.ScaleLength(16),
                10_000);
        }
        Invalidate();
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        base.OnMouseLeave(e);
        _hoverState.PointerExited();
        _openTimer.Stop();
        if (_hoverState.IsExpanded)
        {
            _closeTimer.Stop();
            _closeTimer.Start();
        }
        _hoveredActivityCell = -1;
        _hoveredProjectRow = -1;
        _activityToolTip.Hide(this);
        _projectToolTip.Hide(this);
        Invalidate();
    }

    protected override void OnDpiChanged(DpiChangedEventArgs e)
    {
        base.OnDpiChanged(e);
        RebuildMetrics(e.DeviceDpiNew);
        PositionAtTop();
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        WindowsBackdrop.Apply(Handle);
        RebuildWindowRegion();
    }

    protected override void OnResize(EventArgs e)
    {
        base.OnResize(e);
        RebuildWindowRegion();
        Invalidate();
    }

    private void RebuildMetrics(int dpi)
    {
        _metrics = IslandLayout.For(dpi);
        ClientSize = _expanded ? _metrics.ExpandedSize : _metrics.CompactSize;
        RebuildWindowRegion();
        Invalidate();
    }

    private void AnimateWindow(object? sender, EventArgs e)
    {
        _animationStep++;
        var progress = Math.Min(1d, _animationStep / (double)AnimationSteps);
        var eased = 1 - Math.Pow(1 - progress, 3);
        ClientSize = new Size(
            (int)Math.Round(_animationStart.Width + (_animationTarget.Width - _animationStart.Width) * eased),
            (int)Math.Round(_animationStart.Height + (_animationTarget.Height - _animationStart.Height) * eased));
        PositionAtTop();
        if (_animationStep < AnimationSteps) return;

        _animationTimer.Stop();
        ClientSize = _animationTarget;
        if (!_expanded)
        {
            _renderExpanded = false;
            _hoveredActivityCell = -1;
            _hoveredProjectRow = -1;
            _activityToolTip.Hide(this);
            _projectToolTip.Hide(this);
            Invalidate();
        }
    }

    private void PositionAtTop()
    {
        var area = Screen.FromPoint(Cursor.Position).WorkingArea;
        Location = new Point(
            area.Left + (area.Width - Width) / 2,
            area.Top + _metrics.ScaleLength(8));
    }

    private void RebuildWindowRegion()
    {
        if (ClientSize.Width <= 0 || ClientSize.Height <= 0) return;
        var radius = _metrics.ScaleLength(_expanded ? 22 : 24);
        using var path = Theme.RoundedRectangle(new Rectangle(Point.Empty, ClientSize), radius);
        var previous = Region;
        Region = new Region(path);
        previous?.Dispose();
    }

    private static string FormatTokens(long value) => value switch
    {
        >= 100_000_000 => $"{value / 100_000_000d:0.#}亿",
        >= 10_000 => $"{value / 10_000d:0.#}万",
        >= 1_000 => $"{value / 1_000d:0.#}K",
        _ => value.ToString("N0")
    };

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _animationTimer.Dispose();
            _openTimer.Dispose();
            _closeTimer.Dispose();
            _activityToolTip.Dispose();
            _projectToolTip.Dispose();
        }
        base.Dispose(disposing);
    }
}
