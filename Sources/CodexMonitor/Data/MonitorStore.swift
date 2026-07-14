import Combine
import Foundation

@MainActor
final class MonitorStore: ObservableObject {
    typealias Scanner = @Sendable (URL) async throws -> [SessionSummary]

    @Published private(set) var snapshot: MonitorSnapshot = .empty
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let root: URL
    private let debounceNanoseconds: UInt64
    private let scanner: Scanner
    private var refreshTask: Task<Void, Never>?

    init(
        root: URL,
        debounceNanoseconds: UInt64 = 250_000_000,
        scanner: @escaping Scanner = SessionScanner.scan
    ) {
        self.root = root
        self.debounceNanoseconds = debounceNanoseconds
        self.scanner = scanner
    }

    func requestRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: debounceNanoseconds)
            guard !Task.isCancelled else { return }

            do {
                let sessions = try await scanner(root)
                guard !Task.isCancelled else { return }
                snapshot = UsageAggregator.makeSnapshot(sessions: sessions)
                errorMessage = nil
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = "数据可能已过期"
            }
            isLoading = false
        }
    }

    deinit {
        refreshTask?.cancel()
    }
}
