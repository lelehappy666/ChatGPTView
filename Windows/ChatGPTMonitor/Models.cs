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
    DateTime StartedAt,
    DateTime UpdatedAt,
    long TotalTokens,
    TimeSpan LongestTaskDuration,
    SessionState State,
    double? WeeklyUsedPercent,
    string? WeeklyLimitId,
    DateTime? WeeklyResetsAt);

internal sealed record SessionActivity(
    string Id,
    string ProjectName,
    string DisplayName,
    SessionState State,
    DateTime UpdatedAt);

internal sealed record ProjectActivity(
    string Name,
    SessionState State,
    DateTime UpdatedAt);

internal sealed record UsageDay(DateTime Date, long Tokens, int Sessions);

internal sealed record WeeklyQuota(double? RemainingPercent, DateTime? ResetsAt);

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
