using ChatGPTMonitor;
using System.Drawing;

static void Check(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
}

static SessionActivity Session(
    string id,
    string project,
    SessionState state,
    long timestamp,
    string? turnId)
{
    return new SessionActivity(
        id,
        project,
        id,
        turnId,
        state,
        DateTimeOffset.FromUnixTimeSeconds(timestamp).LocalDateTime);
}

static SessionSummary ParseSession(string contents)
{
    var file = Path.Combine(
        Path.GetTempPath(),
        $"codex-session-hierarchy-{Guid.NewGuid():N}.jsonl");
    try
    {
        File.WriteAllText(file, contents);
        return CodexDataService.ParseSession(file)
            ?? throw new InvalidOperationException("测试会话解析为空");
    }
    finally
    {
        File.Delete(file);
    }
}

foreach (var dpi in new[] { 96, 120, 144, 168, 192 })
{
    var metrics = IslandLayout.For(dpi);
    var scale = dpi / 96f;

    Check(metrics.CompactSize.Width == (int)Math.Round(286 * scale), $"{dpi} DPI 收起宽度错误");
    Check(metrics.CompactSize.Height == (int)Math.Round(48 * scale), $"{dpi} DPI 收起高度错误");
    Check(metrics.ExpandedSize.Width == (int)Math.Round(430 * scale), $"{dpi} DPI 展开宽度错误");
    Check(metrics.ExpandedSize.Height == (int)Math.Round(300 * scale), $"{dpi} DPI 展开高度错误");

    var headerItems = new[]
    {
        metrics.LogoBounds,
        metrics.BrandBounds,
        metrics.QuotaBadgeBounds,
        metrics.ProjectBounds
    };
    for (var index = 1; index < headerItems.Length; index++)
    {
        Check(headerItems[index - 1].Right <= headerItems[index].Left, $"{dpi} DPI 标题元素发生重叠");
    }

    Check(metrics.NavigationTabs.Count == 3, $"{dpi} DPI 标签页数量错误");
    Check(metrics.NavigationTabs.All(metrics.ExpandedClientBounds.Contains), $"{dpi} DPI 标签页越界");
    Check(metrics.StatisticsCards.Count == 4, $"{dpi} DPI 统计卡片数量错误");
    Check(metrics.StatisticsCards.All(metrics.PageSafeBounds.Contains), $"{dpi} DPI 统计卡片越过安全区");

    Check(metrics.QuotaRightBounds.Left - metrics.QuotaLeftBounds.Right >= metrics.ScaleLength(18), $"{dpi} DPI 周额度列间距不足");
    Check(metrics.ActivityMetricsBounds.Width >= metrics.ScaleLength(132), $"{dpi} DPI 活动指标宽度不足");
    Check(metrics.ExpandedSize.Height - metrics.StatisticsCards.Max(card => card.Bottom) >= metrics.ScaleLength(16), $"{dpi} DPI 统计卡片底部空间不足");

    for (var page = 0; page < 3; page++)
    {
        var tab = metrics.NavigationTabs[page];
        Check(metrics.TabAt(new Point(tab.Left + tab.Width / 2, tab.Top + tab.Height / 2)) == page, $"{dpi} DPI 标签命中错误");
    }
    Check(metrics.ActivityCellAt(Point.Empty) == -1, $"{dpi} DPI 活动格外部命中错误");
    for (var index = 0; index < 60; index++)
    {
        var cell = metrics.ActivityCell(index);
        var center = new Point(cell.Left + cell.Width / 2, cell.Top + cell.Height / 2);
        Check(metrics.ActivityCellAt(center) == index, $"{dpi} DPI 第 {index + 1} 个活动格命中错误");
    }
}

var hover = new HoverExpansionState();
hover.PointerEntered();
hover.PointerExited();
Check(hover.OpenDelayElapsed() == HoverExpansionAction.None, "短暂经过不应展开");

hover.PointerEntered();
Check(hover.OpenDelayElapsed() == HoverExpansionAction.ExpandAndRefresh, "稳定悬停应展开并刷新");
Check(hover.OpenDelayElapsed() == HoverExpansionAction.None, "重复移动不能重复刷新");

hover.PointerExited();
hover.PointerEntered();
Check(hover.CloseDelayElapsed() == HoverExpansionAction.None, "收起等待期间重新进入不能收起");

hover.PointerExited();
Check(hover.CloseDelayElapsed() == HoverExpansionAction.Collapse, "移开后应收起");
Check(hover.CloseDelayElapsed() == HoverExpansionAction.None, "已经收起时不能重复收起");

Check(hover.ForceExpanded() == HoverExpansionAction.ExpandAndRefresh, "托盘应主动展开并刷新");
Check(hover.ForceExpanded() == HoverExpansionAction.None, "托盘不能重复展开或刷新");

Check(WindowsBackdrop.SystemBackdropTypeForIsland == 1, "Windows 顶部窗口必须关闭矩形系统背景");
Check(WindowsBackdrop.CornerPreferenceForIsland == 1, "Windows 顶部窗口圆角必须完全由 Region 负责");
Check(WindowsBackdrop.BorderColorForIsland == -2, "Windows 顶部窗口必须关闭 DWM 自动边框");

var sessionFile = Path.Combine(Path.GetTempPath(), $"codex-session-{Guid.NewGuid():N}.jsonl");
try
{
    File.WriteAllText(sessionFile, """
        {"type":"session_meta","payload":{"type":"session_meta","id":"session-456","timestamp":"2026-07-14T06:36:17Z","cwd":"C:\\Projects\\Replaypoker"}}
        {"type":"event_msg","payload":{"type":"user_message","message":"修复牌桌结算状态\n不要改变现有布局"}}
        {"type":"event_msg","payload":{"type":"task_started","turn_id":"turn-123","started_at":1784010977}}
        {"type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-123","completed_at":1784010988}}
        """);

    var summary = CodexDataService.ParseSession(sessionFile);
    Check(summary?.Id == "session-456", "会话 ID 解析错误");
    Check(summary?.TurnId == "turn-123", "轮次 ID 解析错误");
    Check(summary?.DisplayName == "修复牌桌结算状态", "根会话标题解析错误");
}
finally
{
    File.Delete(sessionFile);
}

var missingTurnFile = Path.Combine(
    Path.GetTempPath(),
    $"codex-session-missing-turn-{Guid.NewGuid():N}.jsonl");
try
{
    File.WriteAllText(missingTurnFile, """
        {"type":"session_meta","payload":{"type":"session_meta","id":"session-missing","timestamp":"2026-07-14T06:36:17Z","cwd":"C:\\Projects\\Replaypoker"}}
        {"type":"event_msg","payload":{"type":"task_started","turn_id":"turn-old","started_at":1784010977}}
        {"type":"event_msg","payload":{"type":"task_complete","completed_at":1784010988}}
        """);

    var missingTurnSummary = CodexDataService.ParseSession(missingTurnFile);
    Check(missingTurnSummary?.TurnId is null, "缺少轮次 ID 的最新生命周期不能沿用上一轮身份");
}
finally
{
    File.Delete(missingTurnFile);
}

var newMessageFile = Path.Combine(
    Path.GetTempPath(),
    $"codex-session-new-message-{Guid.NewGuid():N}.jsonl");
try
{
    File.WriteAllText(newMessageFile, """
        {"type":"session_meta","payload":{"type":"session_meta","id":"session-new-message","timestamp":"2026-07-14T06:36:17Z","cwd":"C:\\Projects\\Replaypoker"}}
        {"type":"event_msg","payload":{"type":"user_message","message":"第一轮任务"}}
        {"type":"event_msg","payload":{"type":"task_started","turn_id":"turn-old","started_at":1784010977}}
        {"type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-old","completed_at":1784010988}}
        {"type":"event_msg","payload":{"type":"user_message","message":"继续修复下一轮"}}
        """);

    var newMessageSummary = CodexDataService.ParseSession(newMessageFile);
    Check(newMessageSummary?.State == SessionState.Running, "新用户消息必须立即使上一轮完成状态失效");
    Check(newMessageSummary?.TurnId is null, "新用户消息等待新轮次时不能沿用上一轮 ID");
}
finally
{
    File.Delete(newMessageFile);
}

var rootHierarchySummary = ParseSession("""
    {"type":"session_meta","payload":{"type":"session_meta","id":"root","timestamp":"2026-07-15T02:07:55Z","cwd":"C:\\Projects\\Replaypoker(ios)","source":"vscode"}}
    {"type":"event_msg","payload":{"type":"task_started","turn_id":"root-turn","started_at":1784081275}}
    {"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":1000}}}}
    """);
var childHierarchySummary = ParseSession("""
    {"type":"session_meta","payload":{"type":"session_meta","id":"child","timestamp":"2026-07-15T02:36:42Z","cwd":"C:\\Projects\\Replaypoker(ios)","parent_thread_id":"root","source":{"subagent":{"thread_spawn":{"parent_thread_id":"root"}}}}}
    {"type":"event_msg","payload":{"type":"task_complete","turn_id":"child-turn","completed_at":1784083610}}
    {"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":250}}}}
    """);
var guardianHierarchySummary = ParseSession("""
    {"type":"session_meta","payload":{"type":"session_meta","id":"guardian","timestamp":"2026-07-15T02:37:00Z","cwd":"C:\\Projects\\Replaypoker(ios)","source":{"other":"guardian"}}}
    {"type":"event_msg","payload":{"type":"task_complete","turn_id":"guardian-turn","completed_at":1784083620}}
    """);

Check(rootHierarchySummary.IsTopLevel, "无父会话的 vscode 会话应为顶层");
Check(!childHierarchySummary.IsTopLevel, "thread_spawn 子代理不能成为通知会话");
Check(!guardianHierarchySummary.IsTopLevel, "guardian 不能成为通知会话");
var hierarchySnapshot = CodexDataService.BuildSnapshot(new[]
{
    rootHierarchySummary,
    childHierarchySummary
});
Check(hierarchySnapshot.LifetimeTokens == 1_250, "内部会话 Token 不得从统计中丢失");
Check(
    !hierarchySnapshot.Sessions.Single(item => item.Id == "child").IsTopLevel,
    "内部身份必须传到活动模型");

var completionDetector = new SessionCompletionDetector();
Check(completionDetector.Observe(new[]
{
    Session("a", "项目", SessionState.Completed, 100, "turn-1")
}).Count == 0, "首次完成快照只应建立基线");

var fastCompletion = completionDetector.Observe(new[]
{
    Session("a", "项目", SessionState.Completed, 101, "turn-2")
});
Check(fastCompletion.Count == 1 && fastCompletion[0].TurnId == "turn-2", "漏掉运行快照时仍应识别新完成轮次");
Check(completionDetector.Observe(new[]
{
    Session("a", "项目", SessionState.Completed, 101, "turn-2")
}).Count == 0, "同一完成轮次不能重复通知");

var missingTurnDetector = new SessionCompletionDetector();
Check(missingTurnDetector.Observe(Array.Empty<SessionActivity>()).Count == 0, "空快照应建立基线");
Check(missingTurnDetector.Observe(new[]
{
    Session("missing", "项目", SessionState.Completed, 102, null)
}).Count == 0, "缺少轮次 ID 绝不能通知");

var parallelDetector = new SessionCompletionDetector();
Check(parallelDetector.Observe(Array.Empty<SessionActivity>()).Count == 0, "多会话空快照应建立基线");
var parallelCompletions = parallelDetector.Observe(new[]
{
    Session("first", "同一项目", SessionState.Completed, 103, "turn-a"),
    Session("second", "同一项目", SessionState.Completed, 104, "turn-b")
});
Check(parallelCompletions.Select(item => item.Id).SequenceEqual(new[] { "first", "second" }), "同项目不同会话必须分别通知");

var candidate = Session("confirm", "项目", SessionState.Completed, 200, "turn-old");
var confirmationNow = DateTimeOffset.FromUnixTimeSeconds(203).LocalDateTime;
Check(CompletionConfirmation.Matches(
    candidate,
    candidate,
    confirmationNow,
    TimeSpan.FromSeconds(15)), "未变化的完成轮次应通过复核");
Check(!CompletionConfirmation.Matches(
    candidate,
    Session("confirm", "项目", SessionState.Running, 201, "turn-new"),
    confirmationNow,
    TimeSpan.FromSeconds(15)), "新运行轮次必须拒绝旧候选");
Check(!CompletionConfirmation.Matches(
    candidate,
    Session("confirm", "项目", SessionState.Completed, 201, "turn-old"),
    confirmationNow,
    TimeSpan.FromSeconds(15)), "完成时间变化必须拒绝旧候选");
Check(!CompletionConfirmation.Matches(
    candidate,
    candidate,
    DateTimeOffset.FromUnixTimeSeconds(216).LocalDateTime,
    TimeSpan.FromSeconds(15)), "超过新鲜度的候选必须拒绝");
Check(!CompletionConfirmation.Matches(
    candidate,
    candidate,
    DateTimeOffset.FromUnixTimeSeconds(199).LocalDateTime,
    TimeSpan.FromSeconds(15)), "未来时间的候选必须拒绝");

var firstRefreshStarted = new TaskCompletionSource(
    TaskCreationOptions.RunContinuationsAsynchronously);
var allowFirstRefreshToFinish = new TaskCompletionSource(
    TaskCreationOptions.RunContinuationsAsynchronously);
var refreshCount = 0;
using (var refreshRunner = new CoalescingRefreshRunner(async () =>
{
    var current = Interlocked.Increment(ref refreshCount);
    if (current == 1)
    {
        firstRefreshStarted.TrySetResult();
        await allowFirstRefreshToFinish.Task;
    }
}))
{
    var firstRefresh = refreshRunner.RequestAsync();
    await firstRefreshStarted.Task.WaitAsync(TimeSpan.FromSeconds(2));
    var secondRefresh = refreshRunner.RequestAsync();
    allowFirstRefreshToFinish.TrySetResult();
    await Task.WhenAll(firstRefresh, secondRefresh).WaitAsync(TimeSpan.FromSeconds(2));
}
Check(refreshCount == 2, "扫描期间到达的刷新请求不能丢失");

var latestConfirmedSessions = new List<SessionActivity>
{
    Session("stable", "稳定项目", SessionState.Running, 300, "turn-1")
};
var confirmationRefreshStarted = new TaskCompletionSource(
    TaskCreationOptions.RunContinuationsAsynchronously);
var allowConfirmationRefresh = new TaskCompletionSource(
    TaskCreationOptions.RunContinuationsAsynchronously);
var confirmedNotifications = new List<SessionActivity>();
using (var coordinator = new CompletionNotificationCoordinator(
    requestRefresh: async () =>
    {
        confirmationRefreshStarted.TrySetResult();
        await allowConfirmationRefresh.Task;
    },
    latestSessions: () => latestConfirmedSessions,
    notify: confirmedNotifications.Add,
    now: () => DateTimeOffset.FromUnixTimeSeconds(303).LocalDateTime,
    completionDelay: TimeSpan.Zero,
    refreshSettleDelay: TimeSpan.Zero,
    freshness: TimeSpan.FromSeconds(15)))
{
    coordinator.Observe(latestConfirmedSessions);
    latestConfirmedSessions = new List<SessionActivity>
    {
        Session("stable", "稳定项目", SessionState.Completed, 301, "turn-1")
    };
    coordinator.Observe(latestConfirmedSessions);
    await confirmationRefreshStarted.Task.WaitAsync(TimeSpan.FromSeconds(2));
    Check(confirmedNotifications.Count == 0, "复核刷新完成前不能通知");
    allowConfirmationRefresh.TrySetResult();
    await coordinator.WaitForIdleAsync().WaitAsync(TimeSpan.FromSeconds(2));
}
Check(confirmedNotifications.Count == 1, "稳定完成轮次应且只应通知一次");

var latestSupersededSessions = new List<SessionActivity>
{
    Session("changing", "变化项目", SessionState.Running, 400, "turn-old")
};
var supersededRefreshStarted = new TaskCompletionSource(
    TaskCreationOptions.RunContinuationsAsynchronously);
var allowSupersededRefresh = new TaskCompletionSource(
    TaskCreationOptions.RunContinuationsAsynchronously);
var supersededNotificationCount = 0;
using (var coordinator = new CompletionNotificationCoordinator(
    requestRefresh: async () =>
    {
        supersededRefreshStarted.TrySetResult();
        await allowSupersededRefresh.Task;
    },
    latestSessions: () => latestSupersededSessions,
    notify: _ => supersededNotificationCount++,
    now: () => DateTimeOffset.FromUnixTimeSeconds(403).LocalDateTime,
    completionDelay: TimeSpan.Zero,
    refreshSettleDelay: TimeSpan.Zero,
    freshness: TimeSpan.FromSeconds(15)))
{
    coordinator.Observe(latestSupersededSessions);
    latestSupersededSessions = new List<SessionActivity>
    {
        Session("changing", "变化项目", SessionState.Completed, 401, "turn-old")
    };
    coordinator.Observe(latestSupersededSessions);
    await supersededRefreshStarted.Task.WaitAsync(TimeSpan.FromSeconds(2));
    latestSupersededSessions = new List<SessionActivity>
    {
        Session("changing", "变化项目", SessionState.Running, 402, "turn-new")
    };
    coordinator.Observe(latestSupersededSessions);
    allowSupersededRefresh.TrySetResult();
    await coordinator.WaitForIdleAsync().WaitAsync(TimeSpan.FromSeconds(2));
}
Check(supersededNotificationCount == 0, "同一会话开始新轮次后必须取消旧通知");

Console.WriteLine("全部布局与通知契约检查通过");
