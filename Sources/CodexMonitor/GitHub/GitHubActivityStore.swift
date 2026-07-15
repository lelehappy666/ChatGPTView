import Combine
import Foundation

@MainActor
protocol GitHubActivityCaching: AnyObject {
    func load() -> GitHubActivitySnapshot?
    func save(_ snapshot: GitHubActivitySnapshot)
    func clear()
}

@MainActor
final class UserDefaultsGitHubActivityCache: GitHubActivityCaching {
    private let defaults: UserDefaults
    private let key = "github.activity.snapshot.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> GitHubActivitySnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(GitHubActivitySnapshot.self, from: data)
    }

    func save(_ snapshot: GitHubActivitySnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

@MainActor
final class GitHubActivityStore: ObservableObject {
    enum State: Equatable {
        case unbound(message: String?)
        case loading(cached: GitHubActivitySnapshot?)
        case loaded(GitHubActivitySnapshot)
        case failed(message: String, cached: GitHubActivitySnapshot?)

        var snapshot: GitHubActivitySnapshot? {
            switch self {
            case .unbound:
                return nil
            case .loading(let cached), .failed(_, let cached):
                return cached
            case .loaded(let snapshot):
                return snapshot
            }
        }
    }

    @Published private(set) var state: State = .unbound(message: nil)

    private let loader: any GitHubActivityLoading
    private let credentials: any GitHubCredentialStoring
    private let cache: any GitHubActivityCaching
    private var didLoad = false

    init(
        loader: any GitHubActivityLoading = GitHubGraphQLClient(),
        credentials: any GitHubCredentialStoring = KeychainGitHubCredentialStore(),
        cache: any GitHubActivityCaching = UserDefaultsGitHubActivityCache()
    ) {
        self.loader = loader
        self.credentials = credentials
        self.cache = cache
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await refresh()
    }

    func primeFromCache() {
        guard case .unbound = state,
              let cached = cache.load() else {
            return
        }
        state = .loading(cached: cached)
    }

    func bind(token rawToken: String) async {
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            state = .unbound(message: "剪贴板中没有 GitHub 令牌")
            return
        }

        state = .loading(cached: nil)
        do {
            let snapshot = try await loader.fetchActivity(token: token)
            let credentialStore = credentials
            try await Task.detached(priority: .utility) {
                try credentialStore.saveToken(token)
            }.value
            cache.save(snapshot)
            state = .loaded(snapshot)
            didLoad = true
        } catch GitHubAPIError.invalidToken {
            state = .unbound(message: GitHubAPIError.invalidToken.localizedDescription)
        } catch {
            state = .unbound(message: error.localizedDescription)
        }
    }

    func refresh() async {
        let cached = cache.load()
        let token: String
        do {
            let credentialStore = credentials
            let storedToken = try await Task.detached(priority: .utility) {
                try credentialStore.readToken()
            }.value
            guard let storedToken, !storedToken.isEmpty else {
                state = .unbound(message: nil)
                return
            }
            token = storedToken
        } catch {
            state = .failed(message: error.localizedDescription, cached: cached)
            return
        }

        state = .loading(cached: cached)
        do {
            let snapshot = try await loader.fetchActivity(token: token)
            cache.save(snapshot)
            state = .loaded(snapshot)
        } catch GitHubAPIError.invalidToken {
            let credentialStore = credentials
            try? await Task.detached(priority: .utility) {
                try credentialStore.deleteToken()
            }.value
            cache.clear()
            state = .unbound(message: GitHubAPIError.invalidToken.localizedDescription)
        } catch {
            state = .failed(message: error.localizedDescription, cached: cached)
        }
    }

    func disconnect() {
        try? credentials.deleteToken()
        cache.clear()
        state = .unbound(message: nil)
        didLoad = true
    }
}
