import XCTest
@testable import CodexMonitor

@MainActor
final class GitHubActivityStoreTests: XCTestCase {
    func testBindValidatesBeforeSavingTokenAndPublishesSnapshot() async {
        let snapshot = makeSnapshot(username: "lele")
        let credentials = MemoryCredentialStore()
        let cache = MemoryActivityCache()
        let store = GitHubActivityStore(
            loader: StubActivityLoader(result: .success(snapshot)),
            credentials: credentials,
            cache: cache
        )

        await store.bind(token: "  token-value  ")

        XCTAssertEqual(credentials.token, "token-value")
        XCTAssertEqual(cache.snapshot, snapshot)
        XCTAssertEqual(store.state, .loaded(snapshot))
    }

    func testInvalidTokenIsNeverPersisted() async {
        let credentials = MemoryCredentialStore()
        let store = GitHubActivityStore(
            loader: StubActivityLoader(result: .failure(.invalidToken)),
            credentials: credentials,
            cache: MemoryActivityCache()
        )

        await store.bind(token: "bad-token")

        XCTAssertNil(credentials.token)
        XCTAssertEqual(
            store.state,
            .unbound(message: "GitHub 授权已失效，请重新绑定")
        )
    }

    func testRefreshFailureKeepsCachedSnapshotVisible() async {
        let cached = makeSnapshot(username: "cached")
        let credentials = MemoryCredentialStore(token: "saved-token")
        let cache = MemoryActivityCache(snapshot: cached)
        let store = GitHubActivityStore(
            loader: StubActivityLoader(result: .failure(.server(statusCode: 500))),
            credentials: credentials,
            cache: cache
        )

        await store.loadIfNeeded()

        XCTAssertEqual(
            store.state,
            .failed(message: "GitHub 服务暂时不可用", cached: cached)
        )
        XCTAssertEqual(credentials.token, "saved-token")
    }

    func testDisconnectClearsCredentialCacheAndReturnsToUnbound() {
        let credentials = MemoryCredentialStore(token: "saved-token")
        let cache = MemoryActivityCache(snapshot: makeSnapshot(username: "lele"))
        let store = GitHubActivityStore(
            loader: StubActivityLoader(result: .failure(.invalidToken)),
            credentials: credentials,
            cache: cache
        )

        store.disconnect()

        XCTAssertNil(credentials.token)
        XCTAssertNil(cache.snapshot)
        XCTAssertEqual(store.state, .unbound(message: nil))
    }

    private func makeSnapshot(username: String) -> GitHubActivitySnapshot {
        GitHubActivitySnapshot(
            username: username,
            totalContributions: 12,
            contributionDays: [],
            repositories: [],
            fetchedAt: Date(timeIntervalSince1970: 123)
        )
    }
}

private struct StubActivityLoader: GitHubActivityLoading {
    let result: Result<GitHubActivitySnapshot, GitHubAPIError>

    func fetchActivity(token: String) async throws -> GitHubActivitySnapshot {
        try result.get()
    }
}

private final class MemoryCredentialStore: GitHubCredentialStoring {
    var token: String?

    init(token: String? = nil) {
        self.token = token
    }

    func readToken() throws -> String? { token }
    func saveToken(_ token: String) throws { self.token = token }
    func deleteToken() throws { token = nil }
}

private final class MemoryActivityCache: GitHubActivityCaching {
    var snapshot: GitHubActivitySnapshot?

    init(snapshot: GitHubActivitySnapshot? = nil) {
        self.snapshot = snapshot
    }

    func load() -> GitHubActivitySnapshot? { snapshot }
    func save(_ snapshot: GitHubActivitySnapshot) { self.snapshot = snapshot }
    func clear() { snapshot = nil }
}
