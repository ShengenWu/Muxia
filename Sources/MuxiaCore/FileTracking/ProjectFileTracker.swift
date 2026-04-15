import Foundation

public actor ProjectSnapshotTracker {
    private var lastSnapshots: [String: [String: String]] = [:]
    private let ignoredDirectoryNames: Set<String> = [
        ".git", ".build", "build", "DerivedData", "node_modules", ".cursor", ".codex", "openspec", ".docs"
    ]

    public init() {}

    public func scanProject(at rootURL: URL) throws -> [DetectedFileChange] {
        let rootPath = rootURL.path
        let current = try snapshot(rootURL: rootURL)
        let previous = lastSnapshots[rootPath] ?? [:]
        var changes: [DetectedFileChange] = []

        let allPaths = Set(previous.keys).union(current.keys)
        for path in allPaths.sorted() {
            let oldValue = previous[path]
            let newValue = current[path]
            if oldValue != newValue {
                changes.append(DetectedFileChange(relativePath: path, before: oldValue, after: newValue))
            }
        }

        lastSnapshots[rootPath] = current
        return changes
    }

    private func snapshot(rootURL: URL) throws -> [String: String] {
        let keys: [URLResourceKey] = [.isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return [:]
        }

        var snapshot: [String: String] = [:]
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: Set(keys))
            if values.isDirectory == true {
                if ignoredDirectoryNames.contains(fileURL.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard isTrackableFile(fileURL) else { continue }
            let relativePath = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")
            let contents = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            snapshot[relativePath] = contents
        }
        return snapshot
    }

    private func isTrackableFile(_ fileURL: URL) -> Bool {
        let allowedExtensions: Set<String> = [
            "swift", "md", "txt", "json", "yaml", "yml", "plist", "xcconfig"
        ]
        return allowedExtensions.contains(fileURL.pathExtension.lowercased())
    }
}

public final class ProjectFileWatcher: @unchecked Sendable {
    private let tracker: ProjectSnapshotTracker
    private var tasks: [UUID: Task<Void, Never>] = [:]

    public init(tracker: ProjectSnapshotTracker = ProjectSnapshotTracker()) {
        self.tracker = tracker
    }

    public func startWatching(
        project: ProjectRecord,
        intervalNanoseconds: UInt64 = 1_000_000_000,
        onChange: @escaping @Sendable ([DetectedFileChange]) -> Void
    ) {
        stopWatching(projectID: project.id)
        let url = URL(fileURLWithPath: project.rootPath)
        tasks[project.id] = Task.detached { [tracker] in
            _ = try? await tracker.scanProject(at: url)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
                guard !Task.isCancelled else { break }
                let changes = (try? await tracker.scanProject(at: url)) ?? []
                if !changes.isEmpty {
                    onChange(changes)
                }
            }
        }
    }

    public func stopWatching(projectID: UUID) {
        tasks[projectID]?.cancel()
        tasks[projectID] = nil
    }
}
