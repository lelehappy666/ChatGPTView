import XCTest
@testable import CodexMonitor

final class QuotaRefreshPresentationTests: XCTestCase {
    func testRefreshingDisablesButtonAndShowsProgress() {
        let value = QuotaRefreshPresentation.make(
            refreshState: .refreshing,
            hasQuota: true,
            isFresh: false
        )

        XCTAssertEqual(value.title, "正在刷新…")
        XCTAssertFalse(value.isEnabled)
        XCTAssertTrue(value.showsProgress)
    }

    func testFreshQuotaIsRefreshable() {
        let value = QuotaRefreshPresentation.make(
            refreshState: .updated,
            hasQuota: true,
            isFresh: true
        )

        XCTAssertEqual(value.title, "已同步")
        XCTAssertTrue(value.isEnabled)
        XCTAssertFalse(value.showsProgress)
    }

    func testStaleQuotaRemainsRefreshable() {
        let value = QuotaRefreshPresentation.make(
            refreshState: .idle,
            hasQuota: true,
            isFresh: false
        )

        XCTAssertEqual(value.title, "等待 Codex 更新")
        XCTAssertTrue(value.isEnabled)
    }

    func testUnavailableAndFailureRemainRefreshable() {
        XCTAssertEqual(
            QuotaRefreshPresentation.make(
                refreshState: .idle,
                hasQuota: false,
                isFresh: false
            ).title,
            "暂不可用"
        )
        XCTAssertEqual(
            QuotaRefreshPresentation.make(
                refreshState: .failed,
                hasQuota: true,
                isFresh: false
            ).title,
            "刷新失败"
        )
    }
}
