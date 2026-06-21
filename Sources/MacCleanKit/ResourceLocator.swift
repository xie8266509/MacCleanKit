import Foundation

enum ResourceLocator {
    private static let resourceBundleName = "MacCleanKit_MacCleanKit.bundle"

    static func url(forResource name: String, withExtension ext: String) -> URL? {
        let filename = "\(name).\(ext)"
        let candidates = candidateDirectories().map { directory in
            directory.appendingPathComponent(filename)
        }

        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static func candidateDirectories() -> [URL] {
        var directories: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            directories.append(resourceURL.appendingPathComponent(resourceBundleName, isDirectory: true))
            directories.append(resourceURL)
        }

        directories.append(Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(resourceBundleName)", isDirectory: true))
        directories.append(Bundle.main.bundleURL.appendingPathComponent(resourceBundleName, isDirectory: true))

        if let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent() {
            directories.append(executableDirectory.appendingPathComponent(resourceBundleName, isDirectory: true))
            directories.append(executableDirectory.deletingLastPathComponent().appendingPathComponent(resourceBundleName, isDirectory: true))
        }

        directories.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/MacCleanKit/Resources", isDirectory: true))

        return unique(directories.map(\.standardizedFileURL))
    }

    private static func unique(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { url in
            seen.insert(url.path).inserted
        }
    }
}
