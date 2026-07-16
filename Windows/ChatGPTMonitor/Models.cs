namespace ChatGPTMonitor;

internal enum SessionState
{
    Failed,
    Running,
    Completed
}

internal sealed record SessionSummary(
    string Id,
    string? ProjectName,
    string DisplayName,
    string? TurnId,
    DateTime StartedAt,
    DateTime UpdatedAt,
    long TotalTokens,
    TimeSpan LongestTaskDuration,
    SessionState State,
    double? WeeklyUsedPercent,
    string? WeeklyLimitId,
    DateTime? WeeklyResetsAt,
    bool IsTopLevel = true);

internal sealed record SessionActivity(
    string Id,
    string ProjectName,
    string DisplayName,
    string? TurnId,
    SessionState State,
    DateTime UpdatedAt,
    bool IsTopLevel = true);

internal sealed record ProjectActivity(
    string Name,
    SessionState State,
    DateTime UpdatedAt);

internal sealed record UsageDay(DateTime Date, long Tokens, int Sessions);

internal sealed record WeeklyQuota(double? RemainingPercent, DateTime? ResetsAt);

internal enum ProjectAnalyticsRange
{
    SevenDays,
    ThirtyDays,
    All
}

internal sealed record ProjectAnalyticsRow(
    string Id,
    string Name,
    long Tokens,
    int Sessions,
    int ActiveDays,
    double Share);

internal sealed record ProjectAnalyticsPeriod(
    int ActiveProjects,
    long TotalTokens,
    int TotalSessions,
    IReadOnlyList<ProjectAnalyticsRow> Rows)
{
    public static ProjectAnalyticsPeriod Empty { get; } = new(
        0,
        0,
        0,
        Array.Empty<ProjectAnalyticsRow>());
}

internal sealed record ProjectAnalyticsSnapshot(
    IReadOnlyDictionary<ProjectAnalyticsRange, ProjectAnalyticsPeriod> Periods)
{
    public static ProjectAnalyticsSnapshot Empty { get; } = new(
        new Dictionary<ProjectAnalyticsRange, ProjectAnalyticsPeriod>());

    public ProjectAnalyticsPeriod For(ProjectAnalyticsRange range) =>
        Periods.TryGetValue(range, out var period)
            ? period
            : ProjectAnalyticsPeriod.Empty;
}

internal sealed record MonitorSnapshot(
    WeeklyQuota WeeklyQuota,
    IReadOnlyList<UsageDay> DailyActivity,
    long LifetimeTokens,
    long PeakTokens,
    TimeSpan LongestTaskDuration,
    int CurrentStreakDays,
    int LongestStreakDays,
    IReadOnlyList<ProjectActivity> Projects,
    IReadOnlyList<SessionActivity> Sessions)
{
    public ProjectAnalyticsSnapshot ProjectAnalytics { get; init; } =
        ProjectAnalyticsSnapshot.Empty;

    public static MonitorSnapshot Empty { get; } = new(
        new WeeklyQuota(null, null),
        Array.Empty<UsageDay>(),
        0,
        0,
        TimeSpan.Zero,
        0,
        0,
        Array.Empty<ProjectActivity>(),
        Array.Empty<SessionActivity>());
}
