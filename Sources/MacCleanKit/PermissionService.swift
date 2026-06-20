import AppKit
import Foundation

enum PermissionService {
    static func probeDiskAccess() -> [PermissionProbe] {
        let probes: [(String, String, Bool)] = [
            ("Applications", "/Applications", true),
            ("User Library", "~/Library", true),
            ("Mail Data", "~/Library/Containers/com.apple.mail", true),
            ("Safari Data", "~/Library/Safari", false),
            ("Chrome Data", "~/Library/Application Support/Google/Chrome", false),
            ("Firefox Data", "~/Library/Application Support/Firefox", false),
            ("Xcode Data", "~/Library/Developer/Xcode", false),
            ("Trash", "~/.Trash", true)
        ]

        return probes.map { title, path, important in
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
            let result = probe(url)
            return PermissionProbe(
                id: url.path,
                title: title,
                url: url,
                status: result.status,
                detail: result.detail,
                isImportant: important
            )
        }
    }

    @MainActor
    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func probe(_ url: URL) -> (status: PermissionStatus, detail: String) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            return (.missing, "Path does not exist")
        }

        do {
            if isDirectory(url) {
                _ = try fm.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
            } else {
                _ = try Data(contentsOf: url, options: [.mappedIfSafe])
            }
            return (.available, "Readable")
        } catch {
            return (.limited, error.localizedDescription)
        }
    }

    private static func isDirectory(_ url: URL) -> Bool {
        ((try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false) == true
    }
}
