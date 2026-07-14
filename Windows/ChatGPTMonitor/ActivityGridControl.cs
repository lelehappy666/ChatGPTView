using System.Drawing.Drawing2D;

namespace ChatGPTMonitor;

internal sealed class ActivityGridControl : Control
{
    private readonly ToolTip _toolTip = new()
    {
        InitialDelay = 0,
        ReshowDelay = 0,
        AutoPopDelay = 10_000,
        ShowAlways = true
    };
    private IReadOnlyList<UsageDay> _days = Array.Empty<UsageDay>();
    private int _hoveredIndex = -1;

    public IReadOnlyList<UsageDay> Days
    {
        get => _days;
        set
        {
            _days = value;
            _hoveredIndex = -1;
            Invalidate();
        }
    }

    public ActivityGridControl()
    {
        DoubleBuffered = true;
        BackColor = Theme.Window;
        Size = new Size(236, 112);
        MouseMove += HandleMouseMove;
        MouseLeave += (_, _) =>
        {
            _hoveredIndex = -1;
            _toolTip.Hide(this);
            Invalidate();
        };
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        var cells = BuildCells();
        var maxTokens = Math.Max(1L, cells.Max(item => item?.Tokens ?? 0));

        for (var index = 0; index < cells.Count; index++)
        {
            var rectangle = CellRectangle(index);
            var day = cells[index];
            var level = day is null || day.Tokens == 0
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
            using var brush = new SolidBrush(color);
            using var path = Theme.RoundedRectangle(rectangle, 3);
            e.Graphics.FillPath(brush, path);
            if (index == _hoveredIndex)
            {
                using var pen = new Pen(Theme.Text, 2);
                e.Graphics.DrawPath(pen, path);
            }
        }
    }

    private List<UsageDay?> BuildCells()
    {
        var byDate = _days.ToDictionary(item => item.Date.Date);
        var start = DateTime.Today.AddDays(-59);
        return Enumerable.Range(0, 60)
            .Select(offset => byDate.GetValueOrDefault(start.AddDays(offset)))
            .ToList();
    }

    private Rectangle CellRectangle(int index)
    {
        const int columns = 12;
        const int gap = 4;
        var width = (ClientSize.Width - gap * (columns - 1)) / columns;
        var height = (ClientSize.Height - gap * 4) / 5;
        var column = index % columns;
        var row = index / columns;
        return new Rectangle(column * (width + gap), row * (height + gap), width, height);
    }

    private void HandleMouseMove(object? sender, MouseEventArgs e)
    {
        var cells = BuildCells();
        var next = Enumerable.Range(0, cells.Count)
            .FirstOrDefault(index => CellRectangle(index).Contains(e.Location), -1);
        if (next == _hoveredIndex) return;
        _hoveredIndex = next;
        _toolTip.Hide(this);
        if (next >= 0)
        {
            var date = DateTime.Today.AddDays(-59 + next);
            var day = cells[next];
            var text = day is null
                ? $"{date:yyyy年M月d日}\n无活动"
                : $"{date:yyyy年M月d日}\n{FormatTokens(day.Tokens)} Token · {day.Sessions} 个会话";
            _toolTip.Show(text, this, e.X + 12, e.Y + 16, 10_000);
        }
        Invalidate();
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
        if (disposing) _toolTip.Dispose();
        base.Dispose(disposing);
    }
}
