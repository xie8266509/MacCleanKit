import AppKit
import Foundation

enum DiagnosticService {
    static func export(
        permissionProbes: [PermissionProbe],
        operationLogs: [TrashOperationLog],
        startupBackups: [StartupBackup],
        lastErrorMessage: String?,
        scanStatus: String,
        distributionStatus: DistributionStatus,
        appUpdateInfo: AppUpdateInfo,
        counts: [String: Int]
    ) throws -> URL {
        let bundle = Bundle.main
        let report = DiagnosticReport(
            appName: AppConstants.appName,
            generatedAt: Date(),
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "debug",
            appBuild: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-",
            bundleIdentifier: bundle.bundleIdentifier ?? AppConstants.bundleIdentifier,
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            distributionStatus: distributionStatus,
            appUpdateInfo: appUpdateInfo,
            permissionProbes: permissionProbes.map {
                DiagnosticPermissionProbe(
                    title: $0.title,
                    path: $0.url.path,
                    status: $0.status.rawValue,
                    detail: $0.detail,
                    isImportant: $0.isImportant
                )
            },
            operationLogs: operationLogs,
            startupBackups: startupBackups,
            lastErrorMessage: lastErrorMessage,
            scanStatus: scanStatus,
            counts: counts
        )

        let directory = AppConstants.applicationSupportDirectory.appendingPathComponent("Diagnostics", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "diagnostic-\(ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")).json"
        let url = directory.appendingPathComponent(filename)
        let data = try JSONEncoder.cleaner.encode(report)
        try data.write(to: url, options: [.atomic])
        return url
    }

    @MainActor
    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
