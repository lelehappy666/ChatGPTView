using System.Drawing.Drawing2D;
using System.Media;
using System.Runtime.InteropServices;

namespace ChatGPTMonitor;

internal sealed class TrayController : IDisposable
{
    private readonly NotifyIcon _notifyIcon;
    private readonly Icon _icon;
    private readonly ToolStripMenuItem _startupItem;
    private readonly TopIslandForm _island;
    private readonly Action _refresh;
    private readonly Action _exit;

    public TrayController(TopIslandForm island, Action refresh, Action exit)
    {
        _island = island;
        _refresh = refresh;
        _exit = exit;
        _icon = BuildIcon();

        var menu = new ContextMenuStrip
        {
            Renderer = new DarkMenuRenderer(),
            BackColor = Theme.Surface,
            ForeColor = Theme.Text,
            ShowImageMargin = false
        };
        menu.Items.Add("打开顶部监控", null, (_, _) => OpenMonitor());
        menu.Items.Add("立即刷新数据", null, (_, _) => _refresh());
        menu.Items.Add(new ToolStripSeparator());
        _startupItem = new ToolStripMenuItem("开机自动启动")
        {
            Checked = StartupManager.IsEnabled,
            CheckOnClick = true
        };
        _startupItem.Click += (_, _) =>
        {
            try
            {
                StartupManager.SetEnabled(_startupItem.Checked);
            }
            catch (Exception exception)
            {
                _startupItem.Checked = StartupManager.IsEnabled;
                MessageBox.Show(
                    $"设置开机启动失败：{exception.Message}",
                    "ChatGPT",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
            }
        };
        menu.Items.Add(_startupItem);
        menu.Items.Add("退出", null, (_, _) => _exit());

        _notifyIcon = new NotifyIcon
        {
            Text = "ChatGPT",
            Icon = _icon,
            ContextMenuStrip = menu,
            Visible = true
        };
        _notifyIcon.MouseClick += (_, args) =>
        {
            if (args.Button == MouseButtons.Left) OpenMonitor();
        };
    }

    public void ShowCompletion(SessionActivity session)
    {
        SystemSounds.Asterisk.Play();
        _notifyIcon.BalloonTipTitle = session.ProjectName;
        var sessionLabel = session.DisplayName.EndsWith("会话", StringComparison.Ordinal)
            ? session.DisplayName
            : $"{session.DisplayName} 会话";
        _notifyIcon.BalloonTipText = $"{sessionLabel}已完成";
        _notifyIcon.BalloonTipIcon = ToolTipIcon.Info;
        _notifyIcon.ShowBalloonTip(6_000);
    }

    private void OpenMonitor()
    {
        if (!_island.Visible) _island.Show();
        _island.ToggleExpanded();
        _island.BringToFront();
    }

    private static Icon BuildIcon()
    {
        using var bitmap = new Bitmap(32, 32);
        using (var graphics = Graphics.FromImage(bitmap))
        {
            graphics.SmoothingMode = SmoothingMode.AntiAlias;
            using var path = Theme.RoundedRectangle(new Rectangle(1, 1, 30, 30), 9);
            using var gradient = new LinearGradientBrush(
                new Point(2, 2),
                new Point(30, 30),
                Color.FromArgb(191, 169, 255),
                Color.FromArgb(82, 212, 235));
            graphics.FillPath(gradient, path);
            using var font = new Font("Segoe UI", 15, FontStyle.Bold, GraphicsUnit.Pixel);
            using var brush = new SolidBrush(Theme.Window);
            var text = "C";
            var size = graphics.MeasureString(text, font);
            graphics.DrawString(text, font, brush, (32 - size.Width) / 2, (32 - size.Height) / 2 - 1);
        }

        var handle = bitmap.GetHicon();
        try
        {
            using var temporary = Icon.FromHandle(handle);
            return (Icon)temporary.Clone();
        }
        finally
        {
            DestroyIcon(handle);
        }
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool DestroyIcon(IntPtr handle);

    public void Dispose()
    {
        _notifyIcon.Visible = false;
        _notifyIcon.ContextMenuStrip?.Dispose();
        _notifyIcon.Dispose();
        _icon.Dispose();
    }
}

internal sealed class DarkMenuRenderer : ToolStripProfessionalRenderer
{
    public DarkMenuRenderer() : base(new DarkMenuColors()) { }
}

internal sealed class DarkMenuColors : ProfessionalColorTable
{
    public override Color MenuItemSelected => Theme.SurfaceRaised;
    public override Color MenuItemBorder => Theme.Border;
    public override Color ToolStripDropDownBackground => Theme.Surface;
    public override Color ImageMarginGradientBegin => Theme.Surface;
    public override Color ImageMarginGradientMiddle => Theme.Surface;
    public override Color ImageMarginGradientEnd => Theme.Surface;
    public override Color SeparatorDark => Theme.Border;
    public override Color SeparatorLight => Theme.Border;
}
