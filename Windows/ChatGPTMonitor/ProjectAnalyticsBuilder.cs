namespace ChatGPTMonitor;

internal static class ProjectAnalyticsBuilder
{
    private sealed record ProjectAggregate(
        string Name,
        long Tokens,
        int Sessions,
        HashSet<DateTime> ActiveDates);

    public static ProjectAnalyticsSnapshot Build(
        IReadOnlyList<SessionSummary> summaries,
        DateTime? now = null)
    {
        var today = (now ?? DateTime.Now).Date;
        var newestSessions = summaries
            .Where(item => !string.IsNullOrWhiteSpace(item.ProjectName))
            .GroupBy(item => item.Id, StringComparer.OrdinalIgnoreCase)
            .Select(group => group
                .OrderByDescending(item => item.UpdatedAt)
                .ThenByDescending(item => item.TotalTokens)
                .ThenBy(item => item.ProjectName, StringComparer.OrdinalIgnoreCase)
                .First())
            .ToArray();

        var periods = new Dictionary<ProjectAnalyticsRange, ProjectAnalyticsPeriod>
        {
            [ProjectAnalyticsRange.SevenDays] = BuildPeriod(
                newestSessions,
                today.AddDays(-6)),
            [ProjectAnalyticsRange.ThirtyDays] = BuildPeriod(
                newestSessions,
                today.AddDays(-29)),
            [ProjectAnalyticsRange.All] = BuildPeriod(newestSessions, null)
        };
        return new ProjectAnalyticsSnapshot(periods);
    }

    private static ProjectAnalyticsPeriod BuildPeriod(
        IReadOnlyList<SessionSummary> sessions,
        DateTime? cutoff)
    {
        var projects = sessions
            .Where(item => !cutoff.HasValue || item.StartedAt.Date >= cutoff.Value)
            .GroupBy(item => item.ProjectName!.Trim(), StringComparer.OrdinalIgnoreCase)
            .Select(group => new ProjectAggregate(
                group.Key,
                group.Aggregate(0L, (sum, item) => SafeAdd(sum, Math.Max(0, item.TotalTokens))),
                group.Count(),
                group.Select(item => item.StartedAt.Date).ToHashSet()))
            .OrderByDescending(item => item.Tokens)
            .ThenByDescending(item => item.Sessions)
            .ThenBy(item => item.Name, StringComparer.OrdinalIgnoreCase)
            .ToArray();

        var totalTokens = projects.Aggregate(
            0L,
            (sum, item) => SafeAdd(sum, item.Tokens));
        var totalSessions = projects.Aggregate(
            0,
            (sum, item) => SafeAdd(sum, item.Sessions));

        var visible = projects.Take(6).ToList();
        if (projects.Length > 6)
        {
            visible = projects.Take(5).ToList();
            var remainder = projects.Skip(5).ToArray();
            visible.Add(new ProjectAggregate(
                "其他项目",
                remainder.Aggregate(0L, (sum, item) => SafeAdd(sum, item.Tokens)),
                remainder.Aggregate(0, (sum, item) => SafeAdd(sum, item.Sessions)),
                remainder.SelectMany(item => item.ActiveDates).ToHashSet()));
        }

        var rows = visible.Select((item, index) => new ProjectAnalyticsRow(
            projects.Length > 6 && index == 5 ? "remainder" : $"project:{item.Name}",
            item.Name,
            item.Tokens,
            item.Sessions,
            item.ActiveDates.Count,
            totalTokens > 0 ? item.Tokens / (double)totalTokens : 0))
            .ToArray();

        return new ProjectAnalyticsPeriod(
            projects.Length,
            totalTokens,
            totalSessions,
            rows);
    }

    private static long SafeAdd(long left, long right)
    {
        if (right <= 0) return left;
        return left > long.MaxValue - right ? long.MaxValue : left + right;
    }

    private static int SafeAdd(int left, int right)
    {
        if (right <= 0) return left;
        return left > int.MaxValue - right ? int.MaxValue : left + right;
    }
}
