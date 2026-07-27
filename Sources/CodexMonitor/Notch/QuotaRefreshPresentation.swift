struct QuotaRefreshPresentation: Equatable {
    let title: String
    let isEnabled: Bool
    let showsProgress: Bool

    static func make(
        refreshState: RefreshState,
        hasQuota: Bool,
        isFresh: Bool
    ) -> Self {
        if refreshState == .refreshing {
            return Self(
                title: "正在刷新…",
                isEnabled: false,
                showsProgress: true
            )
        }
        if refreshState == .failed {
            return Self(
                title: "刷新失败",
                isEnabled: true,
                showsProgress: false
            )
        }
        if !hasQuota {
            return Self(
                title: "暂不可用",
                isEnabled: true,
                showsProgress: false
            )
        }
        return Self(
            title: isFresh ? "已同步" : "等待 Codex 更新",
            isEnabled: true,
            showsProgress: false
        )
    }
}
