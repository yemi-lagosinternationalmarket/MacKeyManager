import Foundation

@Observable
public final class FileWatcherService {
    private var watchers: [URL: DispatchSourceFileSystemObject] = [:]
    private var fileDescriptors: [URL: Int32] = [:]
    private var debounceTimers: [URL: DispatchWorkItem] = [:]
    private let debounceInterval: TimeInterval

    public var onFileChanged: ((URL) -> Void)?

    public init(debounceInterval: TimeInterval = 0.5) {
        self.debounceInterval = debounceInterval
    }

    deinit {
        stopAll()
    }

    /// Start watching a file for changes.
    public func watch(url: URL) {
        // Don't double-watch
        guard watchers[url] == nil else { return }
        startWatching(url: url)
    }

    /// Stop watching a specific file.
    public func unwatch(url: URL) {
        stopWatching(url: url)
    }

    /// Stop watching all files.
    public func stopAll() {
        for url in watchers.keys {
            stopWatching(url: url)
        }
    }

    // MARK: - Private

    private func startWatching(url: URL) {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            print("FileWatcher: Failed to open \(url.path)")
            return
        }

        fileDescriptors[url] = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = source.data

            if flags.contains(.delete) || flags.contains(.rename) {
                // File was deleted or renamed (common with atomic saves).
                // Re-establish the watch after a short delay.
                self.stopWatching(url: url)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.startWatching(url: url)
                    self?.debouncedNotify(url: url)
                }
            } else if flags.contains(.write) {
                self.debouncedNotify(url: url)
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        watchers[url] = source
        source.resume()
    }

    private func stopWatching(url: URL) {
        debounceTimers[url]?.cancel()
        debounceTimers.removeValue(forKey: url)

        watchers[url]?.cancel()
        watchers.removeValue(forKey: url)
        fileDescriptors.removeValue(forKey: url)
    }

    private func debouncedNotify(url: URL) {
        debounceTimers[url]?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.onFileChanged?(url)
        }

        debounceTimers[url] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }
}
