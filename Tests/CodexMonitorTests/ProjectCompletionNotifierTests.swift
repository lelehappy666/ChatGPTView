import XCTest
@testable import CodexMonitor

final class ProjectCompletionNotifierTests: XCTestCase {
    func testCompletionNotificationUsesExpectedChineseCopy() {
        XCTAssertEqual(
            CompletionNotificationMessage.message(for: "Codex额度"),
            CompletionNotificationMessage(
                title: "Codex 项目已完成",
                body: "Codex额度 已完成"
            )
        )
    }
}
