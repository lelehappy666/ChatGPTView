import CoreServices
import Foundation

final class SessionDirectoryWatcher: @unchecked Sendable {
    private let root: URL
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "com.dafeng.codexmonitor.session-watcher")
    private var stream: FSEventStreamRef?

    init(root: URL, onChange: @escaping @Sendable () -> Void) {
        self.root = root
        self.onChange = onChange
    }

    @discardableResult
    func start() -> Bool {
        guard stream == nil else { return true }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let paths = [root.path] as CFArray
        guard let createdStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            sessionDirectoryCallback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents |
                kFSEventStreamCreateFlagWatchRoot)
        ) else {
            return false
        }

        stream = createdStream
        FSEventStreamSetDispatchQueue(createdStream, queue)
        return FSEventStreamStart(createdStream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    fileprivate func handleChange() {
        onChange()
    }

    deinit {
        stop()
    }
}

private let sessionDirectoryCallback: FSEventStreamCallback = {
    _, clientInfo, _, _, _, _ in
    guard let clientInfo else { return }
    let watcher = Unmanaged<SessionDirectoryWatcher>
        .fromOpaque(clientInfo)
        .takeUnretainedValue()
    watcher.handleChange()
}
