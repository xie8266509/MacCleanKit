import AppKit
import Foundation
import SwiftUI

@MainActor
final class CleanerStore: ObservableObject {
    @Published var language: AppLanguage = .zh
    @Published var expertMode = true
    @Published var selectedSection: CleanerSection = .applications
    @Published var apps: [InstalledApp] = []
    @Published var selectedAppID: String?
    @Published var associatedFiles: [FileItem] = []
    @Published var startupItems: [FileItem] = []
    @Published var extensionItems: [FileItem] = []
    @Published var leftoverItems: [FileItem] = []
    @Published var cleanupItems: [FileItem] = []
    @Published var diskItems: [DiskUsageItem] = []
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var memoryStats: MemoryStats = .empty
    @Published var updateItems: [UpdateCandidate] = []
    @Published var signatureReport: SignatureReport?
    @Published var permissionProbes: [PermissionProbe] = []
    @Published var operationLogs: [TrashOperationLog] = []
    @Published var startupBackups: [StartupBackup] = []
    @Published var selectedFileIDs: Set<String> = []
    @Published var scanProgress: ScanProgress = .idle
    @Published var isScanning = false
    @Published var isMoving = false
    @Published var statusMessageKey = "last.message.ready"
    @Published var lastErrorMessage: String?
    @Published var showPermissionOnboarding = false

    private var hasStarted = false
    private var scanTask: Task<Void, Never>?
    private var appSizeTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard

    var localizer: Localizer { Localizer(language: language) }

    var selectedApp: InstalledApp? {
        apps.first { $0.id == selectedAppID }
    }

    var statusMessage: String {
        if let lastErrorMessage {
            return lastErrorMessage
        }
        if isScanning, !scanProgress.detail.isEmpty {
            return "\(localizer(scanProgress.messageKey)) \(scanProgress.detail)"
        }
        return localizer(statusMessageKey)
    }

    var selectedTrashItems: [FileItem] {
        selectableItemsForCurrentContext().filter { selectedFileIDs.contains($0.id) && $0.isRemovable }
    }

    var selectedTrashSize: Int64 {
        selectedTrashItems.reduce(into: [String: Int64]()) { result, item in
            result[item.id] = item.size
        }
        .values
        .reduce(0, +)
    }

    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        refreshPermissionProbes()
        if !defaults.bool(forKey: "permissionOnboardingCompleted"),
           permissionProbes.contains(where: { $0.isImportant && $0.status == .limited }) {
            showPermissionOnboarding = true
        }
        reloadOperationLogs()
        reloadStartupBackups()
        refreshMemory()
        refreshApplications()
    }

    func selectSection(_ section: CleanerSection) {
        selectedSection = section
        ensureScanned(section)
    }

    func selectApp(_ app: InstalledApp) {
        guard selectedAppID != app.id else { return }
        selectedAppID = app.id
        refreshSelectedAppDetails()
    }

    func refreshCurrentSection() {
        switch selectedSection {
        case .applications:
            refreshApplications()
        case .memory:
            refreshMemory()
        case .permissions:
            refreshPermissionProbes()
            reloadOperationLogs()
            reloadStartupBackups()
        default:
            scanSection(selectedSection, force: true)
        }
    }

    func refreshApplications() {
        beginScan(messageKey: "scanning.apps", detail: "", fraction: 0.08)
        appSizeTask?.cancel()

        scanTask = Task {
            let scannedApps = await detachedValue {
                ScannerService.scanApplications(calculateSizes: false)
            }

            guard !Task.isCancelled else {
                finishCancelledScan()
                return
            }

            scanProgress = ScanProgress(messageKey: "scanning.apps", detail: "\(scannedApps.count)", fraction: 0.78)
            apps = scannedApps
            updateItems = ScannerService.buildUpdateCandidates(apps: scannedApps)
            if selectedAppID == nil || !scannedApps.contains(where: { $0.id == selectedAppID }) {
                selectedAppID = scannedApps.first?.id
            }
            finishScan()
            refreshSelectedAppDetails()
            refreshApplicationSizesInBackground(scannedApps)
        }
    }

    func refreshSelectedAppDetails() {
        guard let app = selectedApp else {
            associatedFiles = []
            signatureReport = nil
            selectedFileIDs.removeAll()
            return
        }

        beginScan(messageKey: "scanning.associated", detail: app.name, fraction: 0.18)
        let currentID = app.id

        scanTask = Task {
            let quickFiles = await detachedValue {
                ScannerService.scanAssociatedFiles(for: app, calculateSizes: false)
            }

            guard !Task.isCancelled, selectedAppID == currentID else {
                finishCancelledScan()
                return
            }

            associatedFiles = quickFiles
            selectedFileIDs = Set(quickFiles.filter { $0.isRecommended && $0.category != .appBundle && $0.isRemovable }.map(\.id))
            scanProgress = ScanProgress(messageKey: "scanning.associated", detail: app.name, fraction: 0.48)

            async let filesTask: [FileItem] = detachedValue {
                ScannerService.scanAssociatedFiles(for: app, calculateSizes: true)
            }
            async let signatureTask: SignatureReport = detachedValue {
                ScannerService.inspectSignature(for: app)
            }

            let files = await filesTask
            let signature = await signatureTask

            guard !Task.isCancelled, selectedAppID == currentID else {
                finishCancelledScan()
                return
            }

            associatedFiles = files
            selectedFileIDs = Set(files.filter { $0.isRecommended && $0.category != .appBundle && $0.isRemovable }.map(\.id))
            signatureReport = signature
            finishScan()
        }
    }

    func ensureScanned(_ section: CleanerSection) {
        switch section {
        case .applications:
            if apps.isEmpty { refreshApplications() }
        case .startup:
            if startupItems.isEmpty { scanSection(section, force: false) }
        case .extensions:
            if extensionItems.isEmpty { scanSection(section, force: false) }
        case .leftovers:
            if leftoverItems.isEmpty { scanSection(section, force: false) }
        case .cleanup:
            if cleanupItems.isEmpty { scanSection(section, force: false) }
        case .disk:
            if diskItems.isEmpty { scanSection(section, force: false) }
        case .duplicates:
            if duplicateGroups.isEmpty { scanSection(section, force: false) }
        case .memory:
            refreshMemory()
        case .updates:
            if updateItems.isEmpty { updateItems = ScannerService.buildUpdateCandidates(apps: apps) }
        case .permissions:
            refreshPermissionProbes()
            reloadOperationLogs()
            reloadStartupBackups()
        }
    }

    func scanSection(_ section: CleanerSection, force: Bool) {
        selectedFileIDs.removeAll()
        beginScan(messageKey: "scanning.section", detail: section.title(language), fraction: 0.12)
        let currentApps = apps

        scanTask = Task {
            switch section {
            case .startup:
                let result = await detachedValue {
                    ScannerService.scanStartupItems()
                }
                guard !Task.isCancelled else { finishCancelledScan(); return }
                startupItems = result
            case .extensions:
                let result = await detachedValue {
                    ScannerService.scanExtensions()
                }
                guard !Task.isCancelled else { finishCancelledScan(); return }
                extensionItems = result
            case .leftovers:
                let result = await detachedValue {
                    let installedApps = currentApps.isEmpty ? ScannerService.scanApplications() : currentApps
                    return (installedApps, ScannerService.scanLeftovers(installedApps: installedApps))
                }
                guard !Task.isCancelled else { finishCancelledScan(); return }
                if apps.isEmpty {
                    apps = result.0
                    updateItems = ScannerService.buildUpdateCandidates(apps: result.0)
                }
                leftoverItems = result.1
            case .cleanup:
                let result = await detachedValue {
                    ScannerService.scanCleanupItems()
                }
                guard !Task.isCancelled else { finishCancelledScan(); return }
                cleanupItems = result
                selectedFileIDs = Set(result.filter(\.isRecommended).map(\.id))
            case .disk:
                let result = await detachedValue {
                    ScannerService.scanDiskUsage()
                }
                guard !Task.isCancelled else { finishCancelledScan(); return }
                diskItems = result
            case .duplicates:
                let result = await detachedValue {
                    ScannerService.scanDuplicates()
                }
                guard !Task.isCancelled else { finishCancelledScan(); return }
                duplicateGroups = result
            case .updates:
                if currentApps.isEmpty || force {
                    let scannedApps = await detachedValue {
                        ScannerService.scanApplications()
                    }
                    guard !Task.isCancelled else { finishCancelledScan(); return }
                    apps = scannedApps
                    updateItems = ScannerService.buildUpdateCandidates(apps: scannedApps)
                } else {
                    updateItems = ScannerService.buildUpdateCandidates(apps: currentApps)
                }
            case .applications:
                refreshApplications()
                return
            case .memory:
                refreshMemory()
                return
            case .permissions:
                refreshPermissionProbes()
                reloadOperationLogs()
                reloadStartupBackups()
                return
            }

            finishScan()
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        finishCancelledScan()
    }

    func refreshPermissionProbes() {
        permissionProbes = PermissionService.probeDiskAccess()
        statusMessageKey = "last.message.ready"
    }

    func openFullDiskAccessSettings() {
        PermissionService.openFullDiskAccessSettings()
    }

    func openSupportFolder() {
        ScannerService.revealInFinder(AppConstants.applicationSupportDirectory)
    }

    func completePermissionOnboarding() {
        defaults.set(true, forKey: "permissionOnboardingCompleted")
        showPermissionOnboarding = false
    }

    func exportDiagnostics() {
        do {
            let url = try DiagnosticService.export(
                permissionProbes: permissionProbes,
                operationLogs: operationLogs,
                startupBackups: startupBackups,
                lastErrorMessage: lastErrorMessage,
                scanStatus: statusMessage,
                counts: [
                    "apps": apps.count,
                    "associatedFiles": associatedFiles.count,
                    "startupItems": startupItems.count,
                    "extensions": extensionItems.count,
                    "leftovers": leftoverItems.count,
                    "cleanupItems": cleanupItems.count,
                    "diskItems": diskItems.count,
                    "duplicateGroups": duplicateGroups.count,
                    "updates": updateItems.count
                ]
            )
            DiagnosticService.reveal(url)
            statusMessageKey = "last.message.diagnostic.exported"
        } catch {
            lastErrorMessage = "\(localizer("last.message.failed")): \(error.localizedDescription)"
        }
    }

    func reloadOperationLogs() {
        operationLogs = OperationLogStore.load()
    }

    func clearOperationLogs() {
        OperationLogStore.clear()
        reloadOperationLogs()
    }

    func reloadStartupBackups() {
        startupBackups = StartupManager.loadBackups()
    }

    func restoreStartupBackups(_ backups: [StartupBackup]) {
        guard !backups.isEmpty else { return }

        do {
            try StartupManager.restore(backups)
            reloadStartupBackups()
            scanSection(.startup, force: true)
            statusMessageKey = "last.message.restored.startup"
        } catch {
            lastErrorMessage = "\(localizer("last.message.failed")): \(error.localizedDescription)"
        }
    }

    func disableSelectedStartupItems() {
        let items = selectedTrashItems.filter { $0.category == .launchItem }
        guard !items.isEmpty else {
            statusMessageKey = "not.selected"
            return
        }

        do {
            let backups = try StartupManager.disable(items)
            selectedFileIDs.subtract(items.map(\.id))
            startupItems.removeAll { item in backups.contains { $0.originalPath == item.id } }
            reloadStartupBackups()
            statusMessageKey = "last.message.disabled.startup"
        } catch {
            lastErrorMessage = "\(localizer("last.message.failed")): \(error.localizedDescription)"
        }
    }

    func refreshMemory() {
        memoryStats = ScannerService.memoryStats()
        statusMessageKey = "last.message.ready"
    }

    func purgeMemory() {
        isScanning = true
        scanProgress = ScanProgress(messageKey: "memory.warning", detail: "", fraction: nil)
        lastErrorMessage = nil
        Task {
            let purged = await detachedValue {
                ScannerService.runPurge()
            }
            refreshMemory()
            isScanning = false
            statusMessageKey = purged ? "last.message.purged" : "last.message.no.purge"
        }
    }

    func toggleSelection(for item: FileItem) {
        guard item.isRemovable else { return }
        if selectedFileIDs.contains(item.id) {
            selectedFileIDs.remove(item.id)
        } else {
            selectedFileIDs.insert(item.id)
        }
    }

    func selectAllCurrentItems() {
        selectedFileIDs.formUnion(selectableItemsForCurrentContext().filter(\.isRemovable).map(\.id))
    }

    func clearSelection() {
        selectedFileIDs.removeAll()
    }

    func autoSelectDuplicates(policy: DuplicateKeepPolicy) {
        var ids = Set<String>()
        for group in duplicateGroups {
            guard let kept = keptDuplicate(in: group, policy: policy) else { continue }
            ids.formUnion(group.files.filter { $0.id != kept.id }.map(\.id))
        }
        selectedFileIDs = ids
    }

    func selectedTrashURLs() -> [URL] {
        var seen = Set<String>()
        return selectedTrashItems.compactMap { item in
            guard seen.insert(item.id).inserted else { return nil }
            return item.url
        }
    }

    func moveSelectedToTrash() {
        let items = selectedTrashItems
        let urls = selectedTrashURLs()
        guard !urls.isEmpty else {
            statusMessageKey = "not.selected"
            return
        }

        isMoving = true
        lastErrorMessage = nil

        Task {
            do {
                try await TrashService.moveToTrash(urls)
                removeMovedItems(paths: Set(urls.map { $0.standardizedFileURL.path }))
                appendTrashLog(items: items, succeeded: true, error: nil)
                statusMessageKey = "last.message.moved"
            } catch {
                appendTrashLog(items: items, succeeded: false, error: error.localizedDescription)
                lastErrorMessage = "\(localizer("last.message.failed")): \(error.localizedDescription)"
            }
            reloadOperationLogs()
            isMoving = false
        }
    }

    func reveal(_ url: URL) {
        ScannerService.revealInFinder(url)
    }

    func openAppStoreUpdates() {
        if let url = URL(string: "macappstore://showUpdatesPage") {
            NSWorkspace.shared.open(url)
        }
    }

    func selectableItemsForCurrentContext() -> [FileItem] {
        switch selectedSection {
        case .applications:
            associatedFiles
        case .startup:
            startupItems
        case .extensions:
            extensionItems
        case .leftovers:
            leftoverItems
        case .cleanup:
            cleanupItems
        case .duplicates:
            duplicateGroups.flatMap(\.files)
        case .disk, .memory, .updates, .permissions:
            []
        }
    }

    func itemsForSection(_ section: CleanerSection) -> [FileItem] {
        switch section {
        case .applications:
            associatedFiles
        case .startup:
            startupItems
        case .extensions:
            extensionItems
        case .leftovers:
            leftoverItems
        case .cleanup:
            cleanupItems
        case .duplicates:
            duplicateGroups.flatMap(\.files)
        case .disk, .memory, .updates, .permissions:
            []
        }
    }

    private func beginScan(messageKey: String, detail: String, fraction: Double?) {
        scanTask?.cancel()
        isScanning = true
        lastErrorMessage = nil
        statusMessageKey = messageKey
        scanProgress = ScanProgress(messageKey: messageKey, detail: detail, fraction: fraction)
    }

    private func finishScan() {
        isScanning = false
        scanTask = nil
        scanProgress = .idle
        statusMessageKey = "last.message.ready"
    }

    private func finishCancelledScan() {
        isScanning = false
        scanTask = nil
        scanProgress = .idle
        statusMessageKey = "scanning.cancelled"
    }

    private func refreshApplicationSizesInBackground(_ currentApps: [InstalledApp]) {
        appSizeTask?.cancel()
        appSizeTask = Task {
            let sizedApps = await detachedValue {
                ScannerService.enrichApplicationSizes(apps: currentApps)
            }

            guard !Task.isCancelled else { return }
            let sizesByID = Dictionary(uniqueKeysWithValues: sizedApps.map { ($0.id, $0.size) })
            apps = apps.map { app in
                guard let size = sizesByID[app.id] else { return app }
                return app.withSize(size)
            }
            updateItems = ScannerService.buildUpdateCandidates(apps: apps)
        }
    }

    private func appendTrashLog(items: [FileItem], succeeded: Bool, error: String?) {
        OperationLogStore.append(
            TrashOperationLog(
                id: UUID(),
                date: Date(),
                section: selectedSection.rawValue,
                items: items.map {
                    TrashLogItem(path: $0.url.path, name: $0.name, category: $0.category.rawValue, size: $0.size)
                },
                destination: "~/.Trash",
                succeeded: succeeded,
                errorMessage: error
            )
        )
    }

    private func keptDuplicate(in group: DuplicateGroup, policy: DuplicateKeepPolicy) -> FileItem? {
        switch policy {
        case .keepNewest:
            return group.files.max { ($0.modifiedAt ?? .distantPast) < ($1.modifiedAt ?? .distantPast) }
        case .keepShortestPath:
            return group.files.min { $0.url.path.count < $1.url.path.count }
        case .keepLargestFolder:
            let counts = Dictionary(grouping: group.files, by: { $0.url.deletingLastPathComponent().path })
                .mapValues(\.count)
            return group.files.max {
                let lhs = counts[$0.url.deletingLastPathComponent().path] ?? 0
                let rhs = counts[$1.url.deletingLastPathComponent().path] ?? 0
                if lhs == rhs { return $0.url.path.count > $1.url.path.count }
                return lhs < rhs
            }
        }
    }

    private func removeMovedItems(paths: Set<String>) {
        selectedFileIDs.subtract(paths)
        associatedFiles.removeAll { paths.contains($0.id) }
        startupItems.removeAll { paths.contains($0.id) }
        extensionItems.removeAll { paths.contains($0.id) }
        leftoverItems.removeAll { paths.contains($0.id) }
        cleanupItems.removeAll { paths.contains($0.id) }
        duplicateGroups = duplicateGroups.compactMap { group in
            let files = group.files.filter { !paths.contains($0.id) }
            guard files.count > 1 else { return nil }
            return DuplicateGroup(id: group.id, hash: group.hash, size: group.size, files: files)
        }

        apps.removeAll { paths.contains($0.id) }
        updateItems = ScannerService.buildUpdateCandidates(apps: apps)
        if let selectedAppID, paths.contains(selectedAppID) {
            self.selectedAppID = apps.first?.id
            refreshSelectedAppDetails()
        }
    }
}

private func detachedValue<T: Sendable>(_ operation: @escaping @Sendable () -> T) async -> T {
    let worker = Task.detached(priority: .userInitiated) {
        operation()
    }

    return await withTaskCancellationHandler {
        await worker.value
    } onCancel: {
        worker.cancel()
    }
}
