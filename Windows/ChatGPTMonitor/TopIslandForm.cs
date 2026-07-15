using System.Drawing.Drawing2D;

namespace ChatGPTMonitor;

internal sealed class TopIslandForm : Form
{
    private const int AnimationSteps = 12;

    private readonly IslandRenderer _renderer = new();
    private readonly ToolTip _activityToolTip = new()
    {
        InitialDelay = 0,
        ReshowDelay = 0,
        AutoPopDelay = 10_000,
        ShowAlways = true,
        UseAnimation = true,
        UseFading = true
    };
    private readonly System.Windows.Forms.Timer _animationTimer;

    private MonitorSnapshot _snapshot = MonitorSnapshot.Empty;
    private IslandMetrics _metrics;
    private IslandPage _page = IslandPage.Quota;
    private int _hoveredActivityCell = -1;
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

    public TopIslandForm()
    {
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

        Shown += (_, _) =>
        {
            RebuildMetrics(DeviceDpi);
            PositionAtTop();
        };
    }

    public void ToggleExpanded()
    {
        _expanded = !_expanded;
        if (_expanded) _renderExpanded = true;
        _animationStart = ClientSize;
        _animationTarget = _expanded ? _metrics.ExpandedSize : _metrics.CompactSize;
        _animationStep = 0;
        _animationTimer.Start();
        Invalidate();
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
                _hoveredActivityCell));
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        base.OnMouseDown(e);
        if (e.Button != MouseButtons.Left) return;

        if (!_expanded)
        {
            ToggleExpanded();
            return;
        }

        var page = _metrics.TabAt(e.Location);
        if (page >= 0)
        {
            _page = (IslandPage)page;
            _hoveredActivityCell = -1;
            _activityToolTip.Hide(this);
            Invalidate();
            return;
        }

        if (_metrics.HeaderBounds.Contains(e.Location)) ToggleExpanded();
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        var next = _expanded && _page == IslandPage.Activity
            ? _metrics.ActivityCellAt(e.Location)
            : -1;
        if (next == _hoveredActivityCell) return;

        _hoveredActivityCell = next;
        _activityToolTip.Hide(this);
        if (next >= 0)
        {
            var date = DateTime.Today.AddDays(-59 + next);
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
        Invalidate();
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        base.OnMouseLeave(e);
        _hoveredActivityCell = -1;
        _activityToolTip.Hide(this);
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
            _activityToolTip.Hide(this);
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
            _activityToolTip.Dispose();
        }
        base.Dispose(disposing);
    }
}
