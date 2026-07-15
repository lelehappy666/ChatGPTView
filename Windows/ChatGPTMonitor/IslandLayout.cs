using System.Drawing;

namespace ChatGPTMonitor;

internal static class IslandLayout
{
    public static readonly Size LogicalCompactSize = new(286, 48);
    public static readonly Size LogicalExpandedSize = new(430, 300);

    public static IslandMetrics For(int dpi) => new(Math.Max(96, dpi));
}

internal sealed class IslandMetrics
{
    private const int ActivityColumns = 12;
    private const int ActivityRows = 5;
    private const int ActivityGap = 4;
    private const int ActivityCellWidth = 15;
    private const int ActivityCellHeight = 16;

    public IslandMetrics(int dpi)
    {
        Dpi = dpi;
        ScaleFactor = dpi / 96f;
        CompactSize = Scale(IslandLayout.LogicalCompactSize);
        ExpandedSize = Scale(IslandLayout.LogicalExpandedSize);
        CompactClientBounds = new Rectangle(Point.Empty, CompactSize);
        ExpandedClientBounds = new Rectangle(Point.Empty, ExpandedSize);

        LogoBounds = Scale(new Rectangle(12, 10, 28, 28));
        BrandBounds = Scale(new Rectangle(48, 10, 66, 28));
        QuotaBadgeBounds = Scale(new Rectangle(124, 10, 84, 28));
        ProjectBounds = Scale(new Rectangle(218, 10, 58, 28));
        ExpandedProjectBounds = Scale(new Rectangle(218, 10, 194, 28));
        HeaderBounds = Scale(new Rectangle(0, 0, 430, 48));

        NavigationTabs = new[]
        {
            Scale(new Rectangle(18, 56, 82, 30)),
            Scale(new Rectangle(110, 56, 82, 30)),
            Scale(new Rectangle(202, 56, 92, 30))
        };
        PageSafeBounds = Scale(new Rectangle(18, 96, 396, 188));
        QuotaLeftBounds = Scale(new Rectangle(18, 106, 124, 152));
        QuotaRightBounds = Scale(new Rectangle(161, 106, 251, 152));
        ActivityGridBounds = Scale(new Rectangle(18, 124, 224, 96));
        ActivityMetricsBounds = Scale(new Rectangle(268, 106, 144, 152));
        StatisticsCards = new[]
        {
            Scale(new Rectangle(18, 106, 192, 76)),
            Scale(new Rectangle(220, 106, 192, 76)),
            Scale(new Rectangle(18, 194, 192, 76)),
            Scale(new Rectangle(220, 194, 192, 76))
        };
    }

    public int Dpi { get; }
    public float ScaleFactor { get; }
    public Size CompactSize { get; }
    public Size ExpandedSize { get; }
    public Rectangle CompactClientBounds { get; }
    public Rectangle ExpandedClientBounds { get; }
    public Rectangle HeaderBounds { get; }
    public Rectangle LogoBounds { get; }
    public Rectangle BrandBounds { get; }
    public Rectangle QuotaBadgeBounds { get; }
    public Rectangle ProjectBounds { get; }
    public Rectangle ExpandedProjectBounds { get; }
    public IReadOnlyList<Rectangle> NavigationTabs { get; }
    public Rectangle PageSafeBounds { get; }
    public Rectangle QuotaLeftBounds { get; }
    public Rectangle QuotaRightBounds { get; }
    public Rectangle ActivityGridBounds { get; }
    public Rectangle ActivityMetricsBounds { get; }
    public IReadOnlyList<Rectangle> StatisticsCards { get; }

    public int ScaleLength(int value) => (int)Math.Round(value * ScaleFactor);

    public Point Scale(Point value) => new(
        ScaleLength(value.X),
        ScaleLength(value.Y));

    public Size Scale(Size value) => new(
        ScaleLength(value.Width),
        ScaleLength(value.Height));

    public Rectangle Scale(Rectangle value) => new(
        ScaleLength(value.X),
        ScaleLength(value.Y),
        ScaleLength(value.Width),
        ScaleLength(value.Height));

    public int TabAt(Point point)
    {
        for (var index = 0; index < NavigationTabs.Count; index++)
        {
            if (NavigationTabs[index].Contains(point)) return index;
        }
        return -1;
    }

    public Rectangle ActivityCell(int index)
    {
        if (index is < 0 or >= ActivityColumns * ActivityRows) return Rectangle.Empty;
        var column = index % ActivityColumns;
        var row = index / ActivityColumns;
        var logical = new Rectangle(
            18 + column * (ActivityCellWidth + ActivityGap),
            124 + row * (ActivityCellHeight + ActivityGap),
            ActivityCellWidth,
            ActivityCellHeight);
        return Scale(logical);
    }

    public int ActivityCellAt(Point point)
    {
        for (var index = 0; index < ActivityColumns * ActivityRows; index++)
        {
            if (ActivityCell(index).Contains(point)) return index;
        }
        return -1;
    }
}
