using System.Text.Json;

namespace ChatGPTMonitor;

internal sealed class CodexDataService : IDisposable
{
    private sealed record CacheEntry(long Length, DateTime LastWriteUtc, SessionSummary? Summary);

    private readonly string _sessionsRoot = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
        ".codex",
        "sessions");
    private readonly Dictionary<string, CacheEntry> _cache = new(StringComparer.OrdinalIgnoreCase);
    private readonly SessionCompletionDetector _completionDetector = new();
    private readonly CoalescingRefreshRunner _refreshRunner;
    private readonly object _debounceLock = new();
    private FileSystemWatcher? _watcher;
    private System.Threading.Timer? _debounceTimer;
    private bool _disposed;

    public event Action<MonitorSnapshot>? SnapshotChanged;
    public event Action<SessionActivity>? SessionCompleted;

    public CodexDataService()
    {
        _refreshRunner = new CoalescingRefreshRunner(RefreshOnceAsync);
    }

    public void Start()
    {
        if (Directory.Exists(_sessionsRoot))
        {
            _watcher = new FileSystemWatcher(_sessionsRoot, "*.jsonl")
            {
                IncludeSubdirectories = true,
                NotifyFilter = NotifyFilters.FileName |
                    NotifyFilters.LastWrite |
                    NotifyFilters.Size
            };
            _watcher.Changed += OnSessionChanged;
            _watcher.Created += OnSessionChanged;
            _watcher.Deleted += OnSessionChanged;
            _watcher.Renamed += OnSessionChanged;
            _watcher.EnableRaisingEvents = true;
        }

        RequestRefresh(TimeSpan.Zero);
    }

    public void RequestRefresh() => RequestRefresh(TimeSpan.FromMilliseconds(350));

    private void RequestRefresh(TimeSpan delay)
    {
        if (_disposed) return;
        lock (_debounceLock)
        {
            _debounceTimer?.Dispose();
            _debounceTimer = new System.Threading.Timer(
                _ => _ = _refreshRunner.RequestAsync(),
                null,
                delay,
                Timeout.InfiniteTimeSpan);
        }
    }

    private void OnSessionChanged(object sender, FileSystemEventArgs e) => RequestRefresh();

    private async Task RefreshOnceAsync()
    {
        if (_disposed) return;
        var summaries = await Task.Run(ScanSessions);
        if (_disposed) return;
        var snapshot = BuildSnapshot(summaries);
        var completed = _completionDetector.Observe(snapshot.Sessions);
        SnapshotChanged?.Invoke(snapshot);
        foreach (var session in completed)
        {
            SessionCompleted?.Invoke(session);
        }
    }

    private IReadOnlyList<SessionSummary> ScanSessions()
    {
        if (!Directory.Exists(_sessionsRoot)) return Array.Empty<SessionSummary>();

        var currentFiles = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var summaries = new List<SessionSummary>();
        IEnumerable<string> files;
        try
        {
            files = Directory.EnumerateFiles(
                _sessionsRoot,
                "*.jsonl",
                SearchOption.AllDirectories).ToArray();
        }
        catch
        {
            return _cache.Values.Select(entry => entry.Summary).OfType<SessionSummary>().ToArray();
        }

        foreach (var file in files)
        {
            currentFiles.Add(file);
            try
            {
                var info = new FileInfo(file);
                if (_cache.TryGetValue(file, out var cached) &&
                    cached.Length == info.Length &&
                    cached.LastWriteUtc == info.LastWriteTimeUtc)
                {
                    if (cached.Summary is not null) summaries.Add(cached.Summary);
                    continue;
                }

                var summary = ParseSession(file);
                _cache[file] = new CacheEntry(info.Length, info.LastWriteTimeUtc, summary);
                if (summary is not null) summaries.Add(summary);
            }
            catch
            {
                if (_cache.TryGetValue(file, out var cached) && cached.Summary is not null)
                {
                    summaries.Add(cached.Summary);
                }
            }
        }

        foreach (var stale in _cache.Keys.Where(path => !currentFiles.Contains(path)).ToArray())
        {
            _cache.Remove(stale);
        }
        return summaries;
    }

    internal static SessionSummary? ParseSession(string file)
    {
        string? cwd = null;
        string? id = null;
        string? nickname = null;
        string? sessionTitle = null;
        string? turnId = null;
        var startedAt = File.GetCreationTime(file);
        var updatedAt = startedAt;
        var state = SessionState.Completed;
        long tokens = 0;
        var longest = TimeSpan.Zero;
        double? weeklyUsed = null;
        string? weeklyLimitId = null;
        DateTime? weeklyResetsAt = null;

        using var stream = new FileStream(
            file,
            FileMode.Open,
            FileAccess.Read,
            FileShare.ReadWrite | FileShare.Delete);
        using var reader = new StreamReader(stream);

        while (reader.ReadLine() is { } line)
        {
            if (!IsRelevant(line)) continue;
            try
            {
                using var document = JsonDocument.Parse(line);
                var root = document.RootElement;
                if (!root.TryGetProperty("payload", out var payload)) continue;
                var type = GetString(payload, "type") ?? GetString(root, "type");

                switch (type)
                {
                    case "session_meta":
                        cwd = GetString(payload, "cwd") ?? cwd;
                        id = GetString(payload, "id") ?? GetString(payload, "session_id") ?? id;
                        nickname = GetString(payload, "agent_nickname") ?? nickname;
                        if (DateTime.TryParse(GetString(payload, "timestamp"), out var parsed))
                            startedAt = parsed.ToLocalTime();
                        break;
                    case "task_started":
                        turnId = GetString(payload, "turn_id") ?? turnId;
                        state = SessionState.Running;
                        updatedAt = UnixDate(payload, "started_at") ?? updatedAt;
                        break;
                    case "task_complete":
                        turnId = GetString(payload, "turn_id") ?? turnId;
                        state = SessionState.Completed;
                        updatedAt = UnixDate(payload, "completed_at") ?? updatedAt;
                        longest = Max(longest, Duration(payload));
                        break;
                    case "turn_aborted":
                        turnId = GetString(payload, "turn_id") ?? turnId;
                        state = SessionState.Failed;
                        updatedAt = UnixDate(payload, "completed_at") ?? updatedAt;
                        longest = Max(longest, Duration(payload));
                        break;
                    case "token_count":
                        if (payload.TryGetProperty("info", out var info) &&
                            info.TryGetProperty("total_token_usage", out var usage) &&
                            TryGetInt64(usage, "total_tokens", out var total))
                        {
                            tokens = total;
                        }
                        if (payload.TryGetProperty("rate_limits", out var limits))
                        {
                            var weekly = WeeklyWindow(limits);
                            if (weekly.HasValue)
                            {
                                weeklyUsed = weekly.Value.Used;
                                weeklyResetsAt = weekly.Value.Reset;
                                weeklyLimitId = GetString(limits, "limit_id");
                            }
                        }
                        break;
                    case "user_message":
                        sessionTitle ??= ReadableSessionTitle(GetString(payload, "message"));
                        break;
                }
            }
            catch (JsonException)
            {
                // 会话正在写入时可能暂时读到不完整行，下一次刷新会重新解析。
            }
        }

        if (string.IsNullOrWhiteSpace(cwd)) return null;
        var projectName = ProjectName(cwd);
        var sessionId = id ?? Path.GetFileNameWithoutExtension(file);
        var displayName = !string.IsNullOrWhiteSpace(nickname)
            ? nickname.Trim()
            : !string.IsNullOrWhiteSpace(sessionTitle)
                ? sessionTitle
                : $"{startedAt:HH:mm} 会话";
        return new SessionSummary(
            sessionId,
            projectName,
            displayName,
            turnId,
            startedAt,
            updatedAt,
            tokens,
            longest,
            state,
            weeklyUsed,
            weeklyLimitId,
            weeklyResetsAt);
    }

    private static MonitorSnapshot BuildSnapshot(IReadOnlyList<SessionSummary> summaries)
    {
        var quotaCandidates = summaries.Where(item => item.WeeklyUsedPercent.HasValue).ToArray();
        var canonical = quotaCandidates.Where(item => item.WeeklyLimitId == "codex").ToArray();
        var quota = (canonical.Length > 0 ? canonical : quotaCandidates)
            .OrderByDescending(item => item.UpdatedAt)
            .FirstOrDefault();

        var days = summaries
            .GroupBy(item => item.StartedAt.Date)
            .Select(group => new UsageDay(
                group.Key,
                group.Sum(item => item.TotalTokens),
                group.Count()))
            .OrderBy(day => day.Date)
            .ToArray();

        var named = summaries.Where(item => !string.IsNullOrWhiteSpace(item.ProjectName)).ToArray();
        var newestSessions = named
            .GroupBy(item => item.Id)
            .Select(group => group.OrderByDescending(item => item.UpdatedAt).First())
            .Select(item => new SessionActivity(
                item.Id,
                item.ProjectName!,
                item.DisplayName,
                item.TurnId,
                item.State,
                item.UpdatedAt))
            .OrderBy(item => item.UpdatedAt)
            .ToArray();

        var cutoff = DateTime.Now.AddSeconds(-60);
        var projects = named
            .GroupBy(item => item.ProjectName!)
            .Select(group => group.OrderByDescending(item => item.UpdatedAt).First())
            .Where(item => item.UpdatedAt >= cutoff)
            .Select(item => new ProjectActivity(item.ProjectName!, item.State, item.UpdatedAt))
            .OrderBy(item => item.State)
            .ThenByDescending(item => item.UpdatedAt)
            .ToArray();

        var activeDates = days.Where(day => day.Tokens > 0).Select(day => day.Date).ToHashSet();
        var streaks = Streaks(activeDates);
        return new MonitorSnapshot(
            new WeeklyQuota(
                quota?.WeeklyUsedPercent is { } used ? Math.Clamp(100 - used, 0, 100) : null,
                quota?.WeeklyResetsAt),
            days,
            summaries.Sum(item => item.TotalTokens),
            summaries.Count == 0 ? 0 : summaries.Max(item => item.TotalTokens),
            summaries.Count == 0 ? TimeSpan.Zero : summaries.Max(item => item.LongestTaskDuration),
            streaks.Current,
            streaks.Longest,
            projects,
            newestSessions);
    }

    private static (int Current, int Longest) Streaks(HashSet<DateTime> dates)
    {
        var longest = 0;
        var run = 0;
        DateTime? previous = null;
        foreach (var date in dates.OrderBy(value => value))
        {
            run = previous.HasValue && date == previous.Value.AddDays(1) ? run + 1 : 1;
            longest = Math.Max(longest, run);
            previous = date;
        }

        var current = 0;
        for (var cursor = DateTime.Today; dates.Contains(cursor); cursor = cursor.AddDays(-1))
            current++;
        return (current, longest);
    }

    private static bool IsRelevant(string line) =>
        line.Contains("\"type\":\"session_meta\"") ||
        line.Contains("\"type\":\"task_started\"") ||
        line.Contains("\"type\":\"task_complete\"") ||
        line.Contains("\"type\":\"turn_aborted\"") ||
        line.Contains("\"type\":\"user_message\"") ||
        line.Contains("\"type\":\"token_count\"");

    private static string? ReadableSessionTitle(string? message)
    {
        if (string.IsNullOrWhiteSpace(message)) return null;
        var title = message
            .Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries)
            .Select(line => line.Trim())
            .FirstOrDefault(line =>
                line.Length > 0 &&
                !line.StartsWith('<') &&
                !line.StartsWith("# AGENTS", StringComparison.Ordinal));
        return title is null ? null : title[..Math.Min(24, title.Length)];
    }

    private static string? ProjectName(string cwd)
    {
        try
        {
            var full = Path.TrimEndingDirectorySeparator(Path.GetFullPath(cwd));
            var home = Path.TrimEndingDirectorySeparator(Environment.GetFolderPath(
                Environment.SpecialFolder.UserProfile));
            if (string.Equals(full, home, StringComparison.OrdinalIgnoreCase)) return null;
            return new DirectoryInfo(full).Name;
        }
        catch
        {
            return null;
        }
    }

    private static (double Used, DateTime? Reset)? WeeklyWindow(JsonElement limits)
    {
        foreach (var name in new[] { "primary", "secondary" })
        {
            if (!limits.TryGetProperty(name, out var window) ||
                !TryGetInt64(window, "window_minutes", out var minutes) || minutes != 10_080 ||
                !TryGetDouble(window, "used_percent", out var used)) continue;
            return (used, UnixDate(window, "resets_at"));
        }
        return null;
    }

    private static TimeSpan Duration(JsonElement payload) =>
        TryGetDouble(payload, "duration_ms", out var milliseconds)
            ? TimeSpan.FromMilliseconds(milliseconds)
            : TimeSpan.Zero;

    private static TimeSpan Max(TimeSpan left, TimeSpan right) => left > right ? left : right;

    private static DateTime? UnixDate(JsonElement element, string property) =>
        TryGetDouble(element, property, out var value)
            ? DateTimeOffset.FromUnixTimeMilliseconds((long)(value * 1_000)).LocalDateTime
            : null;

    private static string? GetString(JsonElement element, string property) =>
        element.TryGetProperty(property, out var value) && value.ValueKind == JsonValueKind.String
            ? value.GetString()
            : null;

    private static bool TryGetDouble(JsonElement element, string property, out double value)
    {
        value = 0;
        return element.TryGetProperty(property, out var item) && item.TryGetDouble(out value);
    }

    private static bool TryGetInt64(JsonElement element, string property, out long value)
    {
        value = 0;
        return element.TryGetProperty(property, out var item) && item.TryGetInt64(out value);
    }

    public void Dispose()
    {
        _disposed = true;
        _watcher?.Dispose();
        _debounceTimer?.Dispose();
        _refreshRunner.Dispose();
    }
}
