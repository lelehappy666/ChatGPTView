namespace ChatGPTMonitor;

internal enum HoverExpansionAction
{
    None,
    ExpandAndRefresh,
    Collapse
}

internal sealed class HoverExpansionState
{
    private bool _pointerInside;

    public bool IsExpanded { get; private set; }

    public void PointerEntered() => _pointerInside = true;

    public void PointerExited() => _pointerInside = false;

    public HoverExpansionAction OpenDelayElapsed()
    {
        if (!_pointerInside || IsExpanded) return HoverExpansionAction.None;
        IsExpanded = true;
        return HoverExpansionAction.ExpandAndRefresh;
    }

    public HoverExpansionAction CloseDelayElapsed()
    {
        if (_pointerInside || !IsExpanded) return HoverExpansionAction.None;
        IsExpanded = false;
        return HoverExpansionAction.Collapse;
    }

    public HoverExpansionAction ForceExpanded()
    {
        if (IsExpanded) return HoverExpansionAction.None;
        IsExpanded = true;
        return HoverExpansionAction.ExpandAndRefresh;
    }
}
