import Combine
import Foundation

enum RefreshState: Equatable {
    case idle
    case refreshing
    case updated
    case failed
}

@MainActor
final class MonitorStore: ObservableObject {
    typealias Scanner = @Sendable (URL) async throws -> [SessionSummary]

    @Published private(set) var snapshot: MonitorSnapshot = .empty
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    @Published private(set) var refreshState: RefreshState = .idle

    private let root: URL
    private let debounceNanoseconds: UInt64
    private let scanner: Scanner
    private var refreshTask: Task<Void, Never>?
    private var isScanning = false
    private var refreshPending = false

    init(
        root: URL,
        debounceNanoseconds: UInt64 = 250_000_000,
        scanner: Scanner? = nil
    ) {
        self.root = root
        self.debounceNanoseconds = debounceNanoseconds
        if let scanner {
            self.scanner = scanner
        } else {
            let incrementalScanner = IncrementalSessionScanner()
            self.scanner = { root in
                try await incrementalScanner.scan(root: root)
            }
        }
    }

    func requestRefresh() {
        refreshState = .refreshing
        if refreshTask != nil {
            if isScanning { refreshPending = true }
            return
        }

        refreshTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: debounceNanoseconds)
            guard !Task.isCancelled else { return }
            await runRefreshLoop()
        }
    }

    private func runRefreshLoop() async {
        repeat {
            refreshPending = false
            isScanning = true
            do {
                let sessions = try await scanner(root)
                guard !Task.isCancelled else { return }
                snapshot = UsageAggregator.makeSnapshot(sessions: sessions)
                errorMessage = nil
                refreshState = .updated
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = "数据可能已过期"
                refreshState = .failed
            }
            isScanning = false
            isLoading = false
            if refreshPending { refreshState = .refreshing }
        } while refreshPending

        refreshTask = nil
    }

    deinit {
        refreshTask?.cancel()
    }
}
