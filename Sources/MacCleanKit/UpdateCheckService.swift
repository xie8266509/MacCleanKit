import Foundation

enum AppUpdateCheckStatus: String, Codable, Sendable {
    case idle
    case checking
    case current
    case available
    case failed
    case sparkleManaged
}

struct AppUpdateInfo: Codable, Equatable, Sendable {
    let status: AppUpdateCheckStatus
    let currentVersion: String
    let latestVersion: String?
    let releaseName: String?
    let releaseURL: URL?
    let downloadURL: URL?
    let checkedAt: Date?
    let message: String?

    static func idle(currentVersion: String) -> AppUpdateInfo {
        AppUpdateInfo(
            status: .idle,
            currentVersion: currentVersion,
            latestVersion: nil,
            releaseName: nil,
            releaseURL: nil,
            downloadURL: nil,
            checkedAt: nil,
            message: nil
        )
    }

    static func checking(currentVersion: String) -> AppUpdateInfo {
        AppUpdateInfo(
            status: .checking,
            currentVersion: currentVersion,
            latestVersion: nil,
            releaseName: nil,
            releaseURL: nil,
            downloadURL: nil,
            checkedAt: nil,
            message: nil
        )
    }

    static func sparkleManaged(currentVersion: String) -> AppUpdateInfo {
        AppUpdateInfo(
            status: .sparkleManaged,
            currentVersion: currentVersion,
            latestVersion: nil,
            releaseName: nil,
            releaseURL: nil,
            downloadURL: nil,
            checkedAt: Date(),
            message: nil
        )
    }

    static func failed(currentVersion: String, message: String) -> AppUpdateInfo {
        AppUpdateInfo(
            status: .failed,
            currentVersion: currentVersion,
            latestVersion: nil,
            releaseName: nil,
            releaseURL: AppConstants.githubReleasesURL,
            downloadURL: nil,
            checkedAt: Date(),
            message: message
        )
    }
}

enum VersionComparator {
    static func isNewer(_ latest: String, than current: String) -> Bool {
        compare(latest, current) == .orderedDescending
    }

    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = numericComponents(lhs)
        let right = numericComponents(rhs)

        guard !left.isEmpty, !right.isEmpty else {
            return .orderedSame
        }

        for index in 0..<max(left.count, right.count) {
            let leftValue = index < left.count ? left[index] : 0
            let rightValue = index < right.count ? right[index] : 0
            if leftValue > rightValue { return .orderedDescending }
            if leftValue < rightValue { return .orderedAscending }
        }

        return .orderedSame
    }

    private static func numericComponents(_ version: String) -> [Int] {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.hasPrefix("v") || trimmed.hasPrefix("V")
            ? String(trimmed.dropFirst())
            : trimmed
        return normalized
            .split { !$0.isNumber }
            .compactMap { Int($0) }
    }
}

enum UpdateCheckService {
    static func currentVersion() -> String {
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !version.isEmpty {
            return version
        }
        return AppConstants.fallbackAppVersion
    }

    static func checkLatestRelease(currentVersion: String = currentVersion()) async throws -> AppUpdateInfo {
        var request = URLRequest(url: AppConstants.githubLatestReleaseAPI, timeoutInterval: 12)
        request.setValue("MacCleanKit", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw UpdateCheckError.badStatus(httpResponse.statusCode)
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let latestVersion = release.tagName.normalizedReleaseVersion
        let status: AppUpdateCheckStatus = VersionComparator.isNewer(latestVersion, than: currentVersion)
            ? .available
            : .current

        return AppUpdateInfo(
            status: status,
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            releaseName: release.name,
            releaseURL: release.htmlURL,
            downloadURL: release.preferredDownloadURL,
            checkedAt: Date(),
            message: release.body
        )
    }
}

enum UpdateCheckError: LocalizedError {
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .badStatus(let statusCode):
            "GitHub returned HTTP \(statusCode)."
        }
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let htmlURL: URL
    let body: String?
    let assets: [Asset]

    var preferredDownloadURL: URL? {
        assets.first { $0.name.localizedCaseInsensitiveContains(".dmg") }?.browserDownloadURL
            ?? assets.first { $0.name.localizedCaseInsensitiveContains(".app.zip") }?.browserDownloadURL
            ?? assets.first?.browserDownloadURL
    }

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case body
        case assets
    }

    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        private enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }
}

private extension String {
    var normalizedReleaseVersion: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }
}
