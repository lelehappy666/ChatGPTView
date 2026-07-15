namespace ChatGPTMonitor;

internal sealed class SessionCompletionDetector
{
    private HashSet<string>? _seenCompletedTurns;

    public IReadOnlyList<SessionActivity> Observe(IReadOnlyList<SessionActivity> sessions)
    {
        var completedWithIdentity = sessions
            .GroupBy(item => item.Id, StringComparer.OrdinalIgnoreCase)
            .Select(group => group.OrderByDescending(item => item.UpdatedAt).First())
            .Where(item =>
                item.IsTopLevel &&
                item.State == SessionState.Completed &&
                !string.IsNullOrWhiteSpace(item.TurnId))
            .Select(item => (Key: CompletionKey(item), Session: item))
            .OrderBy(item => item.Session.UpdatedAt)
            .ThenBy(item => item.Session.Id, StringComparer.OrdinalIgnoreCase)
            .ToArray();

        if (_seenCompletedTurns is null)
        {
            _seenCompletedTurns = new HashSet<string>(
                completedWithIdentity.Select(item => item.Key),
                StringComparer.OrdinalIgnoreCase);
            return Array.Empty<SessionActivity>();
        }

        var completed = completedWithIdentity
            .Where(item => _seenCompletedTurns.Add(item.Key))
            .Select(item => item.Session)
            .ToArray();
        return completed;
    }

    internal static string CompletionKey(SessionActivity session) =>
        $"{session.Id}::{session.TurnId}";
}

internal static class CompletionConfirmation
{
    public static bool Matches(
        SessionActivity candidate,
        SessionActivity latest,
        DateTime now,
        TimeSpan freshness)
    {
        if (!candidate.IsTopLevel ||
            !latest.IsTopLevel ||
            string.IsNullOrWhiteSpace(candidate.TurnId)) return false;
        var age = now - latest.UpdatedAt;
        return string.Equals(latest.Id, candidate.Id, StringComparison.OrdinalIgnoreCase) &&
            latest.State == SessionState.Completed &&
            string.Equals(latest.TurnId, candidate.TurnId, StringComparison.Ordinal) &&
            latest.UpdatedAt == candidate.UpdatedAt &&
            age >= TimeSpan.Zero &&
            age <= freshness;
    }
}
