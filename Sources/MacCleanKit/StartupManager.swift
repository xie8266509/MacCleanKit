import Foundation

enum StartupManager {
    private static var backupRoot: URL {
        let root = AppConstants.applicationSupportDirectory.appendingPathComponent("Disabled Startup Items", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static var indexURL: URL {
        AppConstants.applicationSupportDirectory.appendingPathComponent("startup-backups.json")
    }

    static func loadBackups() -> [StartupBackup] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        return (try? JSONDecoder.cleaner.decode([StartupBackup].self, from: data)) ?? []
    }

    static func disable(_ items: [FileItem]) throws -> [StartupBackup] {
        let fm = FileManager.default
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let batchDirectory = backupRoot.appendingPathComponent(timestamp, isDirectory: true)
        try fm.createDirectory(at: batchDirectory, withIntermediateDirectories: true)

        var created: [StartupBackup] = []
        for item in items where item.category == .launchItem && item.isRemovable {
            bootout(item.url)
            let destination = uniqueDestination(for: item.url, in: batchDirectory)
            try fm.moveItem(at: item.url, to: destination)
            created.append(
                StartupBackup(
                    id: UUID(),
                    originalPath: item.url.path,
                    backupPath: destination.path,
                    name: item.name,
                    date: Date()
                )
            )
        }

        var backups = loadBackups()
        backups.insert(contentsOf: created, at: 0)
        save(backups)
        return created
    }

    static func restore(_ backups: [StartupBackup]) throws {
        let fm = FileManager.default
        var stored = loadBackups()

        for backup in backups {
            let source = URL(fileURLWithPath: backup.backupPath)
            let destination = URL(fileURLWithPath: backup.originalPath)
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.moveItem(at: source, to: destination)
            bootstrap(destination)
            stored.removeAll { $0.id == backup.id }
        }

        save(stored)
    }

    private static func save(_ backups: [StartupBackup]) {
        guard let data = try? JSONEncoder.cleaner.encode(backups) else { return }
        try? data.write(to: indexURL, options: [.atomic])
    }

    private static func uniqueDestination(for url: URL, in directory: URL) -> URL {
        let fm = FileManager.default
        var destination = directory.appendingPathComponent(url.lastPathComponent)
        var index = 2
        while fm.fileExists(atPath: destination.path) {
            destination = directory.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)-\(index).\(url.pathExtension)")
            index += 1
        }
        return destination
    }

    static func runtimeInfo(for plistURL: URL) -> StartupRuntimeInfo {
        let label = label(in: plistURL)
        let domain = launchctlDomain(for: plistURL)
        guard let label else {
            return StartupRuntimeInfo(label: nil, domain: domain, status: .unknown, detail: domain)
        }

        let result = ProcessRunner.run("/bin/launchctl", arguments: ["print", "\(domain)/\(label)"], timeout: 4)
        if result.status == 0 {
            let stateLine = result.output.lines.first(where: { $0.localizedCaseInsensitiveContains("state =") })
            return StartupRuntimeInfo(label: label, domain: domain, status: .loaded, detail: stateLine ?? "loaded")
        }

        if result.output.localizedCaseInsensitiveContains("could not find service")
            || result.output.localizedCaseInsensitiveContains("does not exist") {
            return StartupRuntimeInfo(label: label, domain: domain, status: .notLoaded, detail: "not loaded")
        }

        return StartupRuntimeInfo(label: label, domain: domain, status: .unknown, detail: result.output.trimmed)
    }

    @discardableResult
    static func bootout(_ plistURL: URL) -> ProcessRunResult {
        ProcessRunner.run("/bin/launchctl", arguments: ["bootout", launchctlDomain(for: plistURL), plistURL.path], timeout: 6)
    }

    @discardableResult
    static func bootstrap(_ plistURL: URL) -> ProcessRunResult {
        ProcessRunner.run("/bin/launchctl", arguments: ["bootstrap", launchctlDomain(for: plistURL), plistURL.path], timeout: 6)
    }

    private static func label(in plistURL: URL) -> String? {
        guard let plist = NSDictionary(contentsOf: plistURL) as? [String: Any] else { return nil }
        return plist["Label"] as? String
    }

    private static func launchctlDomain(for url: URL) -> String {
        if url.path.contains("/LaunchDaemons/") {
            return "system"
        }
        return "gui/\(getuid())"
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var lines: [String] {
        split(whereSeparator: \.isNewline).map(String.init)
    }
}
