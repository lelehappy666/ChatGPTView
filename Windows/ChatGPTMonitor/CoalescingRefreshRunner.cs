namespace ChatGPTMonitor;

internal sealed class CoalescingRefreshRunner : IDisposable
{
    private readonly Func<Task> _operation;
    private readonly object _gate = new();
    private bool _running;
    private bool _pending;
    private bool _disposed;
    private TaskCompletionSource? _pendingCompletion;

    public CoalescingRefreshRunner(Func<Task> operation)
    {
        _operation = operation;
    }

    public Task RequestAsync()
    {
        lock (_gate)
        {
            if (_disposed) return Task.FromCanceled(new CancellationToken(canceled: true));

            _pending = true;
            var completion = _pendingCompletion ??= new TaskCompletionSource(
                TaskCreationOptions.RunContinuationsAsynchronously);
            if (!_running)
            {
                _running = true;
                _ = RunAsync();
            }
            return completion.Task;
        }
    }

    private async Task RunAsync()
    {
        while (true)
        {
            TaskCompletionSource completion;
            lock (_gate)
            {
                if (_disposed || !_pending)
                {
                    _running = false;
                    return;
                }

                _pending = false;
                completion = _pendingCompletion!;
                _pendingCompletion = null;
            }

            try
            {
                await _operation();
                completion.TrySetResult();
            }
            catch (Exception exception)
            {
                completion.TrySetException(exception);
            }
        }
    }

    public void Dispose()
    {
        lock (_gate)
        {
            _disposed = true;
            _pending = false;
            _pendingCompletion?.TrySetCanceled();
            _pendingCompletion = null;
        }
    }
}
