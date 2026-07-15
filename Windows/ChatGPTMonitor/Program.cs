namespace ChatGPTMonitor;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new MonitorApplicationContext());
    }
}

internal sealed class MonitorApplicationContext : ApplicationContext
{
    private readonly CodexDataService _dataService;
    private readonly TopIslandForm _island;
    private readonly TrayController _tray;

    public MonitorApplicationContext()
    {
        _dataService = new CodexDataService();
        _island = new TopIslandForm(() => _dataService.RequestRefresh());
        _tray = new TrayController(
            _island,
            () => _dataService.RequestRefresh(),
            ExitThread);

        _dataService.SnapshotChanged += snapshot =>
        {
            if (_island.IsDisposed) return;
            _island.BeginInvoke(new Action(() => _island.UpdateSnapshot(snapshot)));
        };
        _dataService.SessionCompleted += session =>
        {
            if (_island.IsDisposed) return;
            _island.BeginInvoke(new Action(() => _tray.ShowCompletion(session)));
        };

        _island.Show();
        _dataService.Start();
    }

    protected override void ExitThreadCore()
    {
        _dataService.Dispose();
        _tray.Dispose();
        _island.Close();
        _island.Dispose();
        base.ExitThreadCore();
    }
}
