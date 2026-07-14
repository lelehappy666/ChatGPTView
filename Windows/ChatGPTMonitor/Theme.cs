using System.Drawing.Drawing2D;

namespace ChatGPTMonitor;

internal static class Theme
{
    public static readonly Color Window = Color.FromArgb(8, 10, 15);
    public static readonly Color Surface = Color.FromArgb(18, 21, 29);
    public static readonly Color SurfaceRaised = Color.FromArgb(25, 29, 39);
    public static readonly Color Border = Color.FromArgb(53, 58, 72);
    public static readonly Color Text = Color.FromArgb(245, 247, 252);
    public static readonly Color Muted = Color.FromArgb(163, 171, 190);
    public static readonly Color Purple = Color.FromArgb(165, 138, 245);
    public static readonly Color Green = Color.FromArgb(79, 220, 146);
    public static readonly Color Orange = Color.FromArgb(255, 166, 72);
    public static readonly Color Red = Color.FromArgb(255, 102, 123);

    public static Font Font(float size, FontStyle style = FontStyle.Regular) =>
        new("Segoe UI Variable", size, style, GraphicsUnit.Point);

    public static GraphicsPath RoundedRectangle(Rectangle bounds, int radius)
    {
        var diameter = Math.Max(2, radius * 2);
        var path = new GraphicsPath();
        path.AddArc(bounds.Left, bounds.Top, diameter, diameter, 180, 90);
        path.AddArc(bounds.Right - diameter, bounds.Top, diameter, diameter, 270, 90);
        path.AddArc(bounds.Right - diameter, bounds.Bottom - diameter, diameter, diameter, 0, 90);
        path.AddArc(bounds.Left, bounds.Bottom - diameter, diameter, diameter, 90, 90);
        path.CloseFigure();
        return path;
    }

    public static void ApplyRoundedRegion(Control control, int radius)
    {
        using var path = RoundedRectangle(new Rectangle(Point.Empty, control.Size), radius);
        var old = control.Region;
        control.Region = new Region(path);
        old?.Dispose();
    }
}
