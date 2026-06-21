import Foundation

enum AppConstants {
    static let appName = "MacCleanKit"
    static let author = "Linux do @MIKE2026"
    static let bundleIdentifier = "com.local.maccleankit"
    static let fallbackAppVersion = "0.1.3"
    static let githubLatestReleaseAPI = URL(string: "https://api.github.com/repos/xie8266509/MacCleanKit/releases/latest")!
    static let githubReleasesURL = URL(string: "https://github.com/xie8266509/MacCleanKit/releases")!

    static var applicationSupportDirectory: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let directory = root.appendingPathComponent(appName, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
