namespace ChatGPTMonitor;

internal sealed class CompletionNotificationCoordinator : IDisposable
{
    private sealed class PendingCompletion
    {
        public PendingCompletion(SessionActivity candidate)
        {
            Candidate = candidate;
        }

        public SessionActivity Candidate { get; }
        public CancellationTokenSource Cancellation { get; } = new();
        public Task Work { get; set; } = Task.CompletedTask;
    }

    private readonly Func<Task> _requestRefresh;
    private readonly Func<IReadOnlyList<SessionActivity>> _latestSessions;
    private readonly Action<SessionActivity> _notify;
    private readonly Func<DateTime> _now;
    private readonly Func<TimeSpan, CancellationToken, Task> _delay;
    private readonly TimeSpan _completionDelay;
    private readonly TimeSpan _refreshSettleDelay;
    private readonly TimeSpan _freshness;
    private readonly SessionCompletionDetector _detector = new();
    private readonly Dictionary<string, PendingCompletion> _pending =
        new(StringComparer.OrdinalIgnoreCase);
    private readonly object _gate = new();
    private bool _disposed;

    public CompletionNotificationCoordinator(
        Func<Task> requestRefresh,
        Func<IReadOnlyList<SessionActivity>> latestSessions,
        Action<SessionActivity> notify,
        Func<DateTime>? now = null,
        TimeSpan? completionDelay = null,
        TimeSpan? refreshSettleDelay = null,
        TimeSpan? freshness = null,
        Func<TimeSpan, CancellationToken, Task>? delay = null)
    {
        _requestRefresh = requestRefresh;
        _latestSessions = latestSessions;
        _notify = notify;
        _now = now ?? (() => DateTime.Now);
        _completionDelay = completionDelay ?? TimeSpan.FromSeconds(3);
        _refreshSettleDelay = refreshSettleDelay ?? TimeSpan.FromSeconds(1);
        _freshness = freshness ?? TimeSpan.FromSeconds(15);
        _delay = delay ?? ((duration, token) => Task.Delay(duration, token));
    }

    public void Observe(IReadOnlyList<SessionActivity> sessions)
    {
        lock (_gate)
        {
            if (_disposed) return;
            CancelInvalidPending(sessions);

            foreach (var candidate in _detector.Observe(sessions))
            {
                var age = _now() - candidate.UpdatedAt;
                if (age < TimeSpan.Zero || age > _freshness) continue;

                var key = SessionCompletionDetector.CompletionKey(candidate);
                if (_pending.ContainsKey(key)) continue;
                var pending = new PendingCompletion(candidate);
                _pending[key] = pending;
                pending.Work = ConfirmAsync(key, pending);
            }
        }
    }

    private void CancelInvalidPending(IReadOnlyList<SessionActivity> sessions)
    {
        var latestBySession = sessions
            .GroupBy(item => item.Id, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(
                group => group.Key,
                group => group.OrderByDescending(item => item.UpdatedAt).First(),
                StringComparer.OrdinalIgnoreCase);

        foreach (var entry in _pending)
        {
            var candidate = entry.Value.Candidate;
            if (!latestBySession.TryGetValue(candidate.Id, out var latest) ||
                !latest.IsTopLevel ||
                latest.State != SessionState.Completed ||
                !string.Equals(latest.TurnId, candidate.TurnId, StringComparison.Ordinal) ||
                latest.UpdatedAt != candidate.UpdatedAt)
            {
                entry.Value.Cancellation.Cancel();
            }
        }
    }

    private async Task ConfirmAsync(string key, PendingCompletion pending)
    {
        await Task.Yield();
        try
        {
            await _delay(_completionDelay, pending.Cancellation.Token);
            pending.Cancellation.Token.ThrowIfCancellationRequested();
            await _requestRefresh();
            pending.Cancellation.Token.ThrowIfCancellationRequested();
            await _delay(_refreshSettleDelay, pending.Cancellation.Token);
            pending.Cancellation.Token.ThrowIfCancellationRequested();

            var latest = _latestSessions()
                .Where(item => string.Equals(
                    item.Id,
                    pending.Candidate.Id,
                    StringComparison.OrdinalIgnoreCase))
                .OrderByDescending(item => item.UpdatedAt)
                .FirstOrDefault();
            if (latest is null || !CompletionConfirmation.Matches(
                    pending.Candidate,
                    latest,
                    _now(),
                    _freshness))
            {
                return;
            }

            lock (_gate)
            {
                if (_disposed ||
                    pending.Cancellation.IsCancellationRequested ||
                    !_pending.TryGetValue(key, out var current) ||
                    !ReferenceEquals(current, pending))
                {
                    return;
                }
                _notify(pending.Candidate);
            }
        }
        catch (OperationCanceledException)
        {
            // 新轮次或应用退出会取消尚未确认的通知。
        }
        finally
        {
            lock (_gate)
            {
                if (_pending.TryGetValue(key, out var current) &&
                    ReferenceEquals(current, pending))
                {
                    _pending.Remove(key);
                }
            }
            pending.Cancellation.Dispose();
        }
    }

    internal async Task WaitForIdleAsync()
    {
        while (true)
        {
            Task[] work;
            lock (_gate)
            {
                work = _pending.Values.Select(item => item.Work).ToArray();
            }
            if (work.Length == 0) return;
            try
            {
                await Task.WhenAll(work);
            }
            catch (OperationCanceledException)
            {
                // 等待所有取消任务完成清理。
            }
        }
    }

    public void Dispose()
    {
        lock (_gate)
        {
            if (_disposed) return;
            _disposed = true;
            foreach (var pending in _pending.Values)
            {
                pending.Cancellation.Cancel();
            }
        }
    }
}
