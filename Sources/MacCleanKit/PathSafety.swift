import Foundation

enum PathSafetyError: LocalizedError {
    case unsafeTrashTarget(URL, ProtectionReason)

    var errorDescription: String? {
        switch self {
        case let .unsafeTrashTarget(url, reason):
            "\(url.path) is blocked by safety policy: \(reason.rawValue)"
        }
    }
}

enum PathSafety {
    static func protectionReasons(for url: URL) -> [ProtectionReason] {
        let path = url.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        var reasons: [ProtectionReason] = []

        if systemPathPrefixes.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
            reasons.append(.systemPath)
        }

        if protectedExactRoots.contains(path) || path == home {
            reasons.append(.protectedRoot)
        }

        let userRoots = userContentRoots(home: home)
        if userRoots.contains(path) {
            reasons.append(.userContentRoot)
        }

        return Array(Set(reasons))
    }

    static func validateTrashTargets(_ urls: [URL]) throws {
        for url in urls {
            if let reason = protectionReasons(for: url).first {
                throw PathSafetyError.unsafeTrashTarget(url, reason)
            }
        }
    }

    private static let protectedExactRoots: Set<String> = [
        "/",
        "/Applications",
        "/Library",
        "/Network",
        "/System",
        "/Users",
        "/Users/Shared",
        "/Volumes",
        "/bin",
        "/etc",
        "/private",
        "/sbin",
        "/tmp",
        "/usr",
        "/var"
    ]

    private static let systemPathPrefixes: [String] = [
        "/System",
        "/bin",
        "/sbin",
        "/usr/bin",
        "/usr/lib",
        "/usr/sbin",
        "/private/etc",
        "/private/var/db",
        "/private/var/root"
    ]

    private static func userContentRoots(home: String) -> Set<String> {
        [
            "Desktop",
            "Documents",
            "Downloads",
            "Movies",
            "Music",
            "Pictures",
            "Public"
        ].reduce(into: Set<String>()) { roots, component in
            roots.insert("\(home)/\(component)")
        }
    }
}
