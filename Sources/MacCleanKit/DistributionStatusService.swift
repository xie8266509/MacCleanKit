import Foundation

enum DistributionStatusService {
    static func inspectCurrentApp() -> DistributionStatus {
        let bundle = Bundle.main
        let appURL = appBundleURL(bundle: bundle)
        let targetPath = appURL.path
        let bundleIdentifier = bundle.bundleIdentifier ?? AppConstants.bundleIdentifier
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? AppConstants.fallbackAppVersion
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        let macOSVersion = ProcessInfo.processInfo.operatingSystemVersionString

        let codesign = ProcessRunner.run(
            "/usr/bin/codesign",
            arguments: ["--verify", "--deep", "--strict", "--verbose=2", targetPath],
            timeout: 8
        )
        let details = ProcessRunner.run(
            "/usr/bin/codesign",
            arguments: ["-dv", "--verbose=4", targetPath],
            timeout: 8
        )
        let gatekeeper = ProcessRunner.run(
            "/usr/sbin/spctl",
            arguments: ["-a", "-vv", "-t", "execute", targetPath],
            timeout: 8
        )
        let quarantine = ProcessRunner.run(
            "/usr/bin/xattr",
            arguments: ["-p", "com.apple.quarantine", targetPath],
            timeout: 4
        )

        return DistributionStatus(
            appPath: targetPath,
            bundleIdentifier: bundleIdentifier,
            version: version,
            build: build,
            macOSVersion: macOSVersion,
            signingStatus: signingStatus(codesign: codesign, details: details),
            codesignSummary: summary(for: codesign, successMessage: "valid on disk"),
            gatekeeperSummary: summary(for: gatekeeper, successMessage: "accepted"),
            isGatekeeperAccepted: gatekeeper.status == 0,
            isQuarantined: quarantine.status == 0,
            quarantineValue: quarantine.status == 0 ? quarantine.output.trimmed : nil
        )
    }

    private static func appBundleURL(bundle: Bundle) -> URL {
        let bundleURL = bundle.bundleURL.standardizedFileURL
        if bundleURL.pathExtension == "app" {
            return bundleURL
        }

        if let executableURL = bundle.executableURL {
            let components = executableURL.standardizedFileURL.pathComponents
            if let appIndex = components.lastIndex(where: { $0.hasSuffix(".app") }) {
                let path = "/" + components.prefix(appIndex + 1).dropFirst().joined(separator: "/")
                return URL(fileURLWithPath: path).standardizedFileURL
            }
        }

        return bundleURL
    }

    private static func signingStatus(codesign: ProcessRunResult, details: ProcessRunResult) -> DistributionSigningStatus {
        let output = "\(codesign.output)\n\(details.output)"
        if output.localizedCaseInsensitiveContains("Developer ID Application") {
            return .developerID
        }
        if output.localizedCaseInsensitiveContains("Signature=adhoc") || output.localizedCaseInsensitiveContains("adhoc") {
            return .adHoc
        }
        if codesign.status != 0, output.localizedCaseInsensitiveContains("code object is not signed") {
            return .unsigned
        }
        if codesign.status == 0 {
            return .unknown
        }
        return .unsigned
    }

    private static func summary(for result: ProcessRunResult, successMessage: String) -> String {
        let output = result.output.trimmed
        if result.status == 0 {
            return output.isEmpty ? successMessage : output
        }
        return output.isEmpty ? "status \(result.status)" : output
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
