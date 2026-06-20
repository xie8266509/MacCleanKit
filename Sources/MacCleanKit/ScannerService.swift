import CryptoKit
import AppKit
import Darwin
import Foundation

enum ScannerService {
    private static var fm: FileManager { FileManager.default }
    private static let sizeCacheQueue = DispatchQueue(label: "MacCleanKit.size-cache")
    nonisolated(unsafe) private static var sizeCache: [String: SizeCacheEntry] = [:]
    nonisolated(unsafe) private static var didLoadSizeCache = false
    nonisolated(unsafe) private static var pendingSizeCacheWrites = 0

    static func scanApplications(calculateSizes: Bool = false) -> [InstalledApp] {
        let roots = [
            fileURL("/Applications"),
            fileURL("/System/Applications"),
            fileURL("/System/Applications/Utilities"),
            fileURL("~/Applications")
        ]

        var appURLs: [URL] = []
        var seen = Set<String>()

        for root in roots where fm.fileExists(atPath: root.path) {
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator {
                if Task.isCancelled { break }
                if url.pathExtension.lowercased() == "app" {
                    let key = url.standardizedFileURL.path
                    if seen.insert(key).inserted {
                        appURLs.append(url)
                    }
                    enumerator.skipDescendants()
                }
            }
        }

        return appURLs.compactMap { makeInstalledApp(from: $0, calculateSize: calculateSizes) }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    static func enrichApplicationSizes(apps: [InstalledApp]) -> [InstalledApp] {
        let sizedApps = apps.map { app in
            if Task.isCancelled { return app }
            let size = itemSize(of: app.url, calculate: true)
            return app.withSize(size)
        }
        flushSizeCache()
        return sizedApps
    }

    static func scanAssociatedFiles(for app: InstalledApp, calculateSizes: Bool = true) -> [FileItem] {
        let library = fileURL("~/Library")
        let support = library.appendingPathComponent("Application Support")
        let caches = library.appendingPathComponent("Caches")
        let preferences = library.appendingPathComponent("Preferences")
        let byHostPreferences = preferences.appendingPathComponent("ByHost")
        let logs = library.appendingPathComponent("Logs")
        let containers = library.appendingPathComponent("Containers")
        let groupContainers = library.appendingPathComponent("Group Containers")
        let httpStorages = library.appendingPathComponent("HTTPStorages")
        let webKit = library.appendingPathComponent("WebKit")
        let cookies = library.appendingPathComponent("Cookies")
        let launchAgents = library.appendingPathComponent("LaunchAgents")
        let savedState = library.appendingPathComponent("Saved Application State")
        let applicationScripts = library.appendingPathComponent("Application Scripts")

        let names = candidateNames(for: app)
        var items: [FileItem] = []
        var seen = Set<String>()

        func appendIfExists(_ url: URL, category: FileCategory, detail: String? = nil, recommended: Bool = false) {
            guard fm.fileExists(atPath: url.path), seen.insert(url.standardizedFileURL.path).inserted else { return }
            let size = itemSize(of: url, calculate: calculateSizes)
            let reasons = protectionReasons(for: url, category: category, size: size, app: app, recommended: recommended)
            items.append(
                FileItem(
                    url: url,
                    category: category,
                    size: size,
                    modifiedAt: modificationDate(of: url),
                    detail: detail,
                    isRecommended: recommended,
                    isRemovable: true,
                    protectionReasons: reasons
                )
            )
        }

        if let bundleID = app.bundleIdentifier, !bundleID.isEmpty {
            appendIfExists(app.url, category: .appBundle, detail: bundleID, recommended: false)
            appendIfExists(support.appendingPathComponent(bundleID), category: .applicationSupport, detail: bundleID)
            appendIfExists(caches.appendingPathComponent(bundleID), category: .cache, detail: bundleID, recommended: true)
            appendIfExists(preferences.appendingPathComponent("\(bundleID).plist"), category: .preferences, detail: bundleID)
            appendIfExists(logs.appendingPathComponent(bundleID), category: .logs, detail: bundleID, recommended: true)
            appendIfExists(containers.appendingPathComponent(bundleID), category: .container, detail: bundleID)
            appendIfExists(httpStorages.appendingPathComponent(bundleID), category: .cache, detail: bundleID, recommended: true)
            appendIfExists(webKit.appendingPathComponent(bundleID), category: .cache, detail: bundleID, recommended: true)
            appendIfExists(cookies.appendingPathComponent("\(bundleID).binarycookies"), category: .cache, detail: bundleID, recommended: true)
            appendIfExists(launchAgents.appendingPathComponent("\(bundleID).plist"), category: .launchItem, detail: bundleID)
            appendIfExists(savedState.appendingPathComponent("\(bundleID).savedState"), category: .leftover, detail: bundleID, recommended: true)
            appendIfExists(applicationScripts.appendingPathComponent(bundleID), category: .applicationSupport, detail: bundleID)

            for child in immediateChildren(of: byHostPreferences) {
                let lower = child.lastPathComponent.lowercased()
                if lower.hasPrefix(bundleID.lowercased() + ".") && lower.hasSuffix(".plist") {
                    appendIfExists(child, category: .preferences, detail: "ByHost · \(bundleID)")
                }
            }

            for root in [fileURL("/Library/LaunchAgents"), fileURL("/Library/LaunchDaemons")] {
                appendIfExists(root.appendingPathComponent("\(bundleID).plist"), category: .launchItem, detail: bundleID)
            }
        } else {
            appendIfExists(app.url, category: .appBundle, detail: app.name, recommended: false)
        }

        for name in names where !name.isEmpty {
            appendIfExists(support.appendingPathComponent(name), category: .applicationSupport, detail: name)
            appendIfExists(caches.appendingPathComponent(name), category: .cache, detail: name, recommended: true)
            appendIfExists(logs.appendingPathComponent(name), category: .logs, detail: name, recommended: true)
            appendIfExists(preferences.appendingPathComponent("\(name).plist"), category: .preferences, detail: name)
            appendIfExists(httpStorages.appendingPathComponent(name), category: .cache, detail: name, recommended: true)
            appendIfExists(webKit.appendingPathComponent(name), category: .cache, detail: name, recommended: true)
            appendIfExists(savedState.appendingPathComponent("\(name).savedState"), category: .leftover, detail: name, recommended: true)
            appendIfExists(applicationScripts.appendingPathComponent(name), category: .applicationSupport, detail: name)
        }

        for rule in RuleStore.rules(for: app.bundleIdentifier) {
            for path in rule.paths {
                appendIfExists(
                    expandRulePath(path.path, app: app),
                    category: RuleStore.category(from: path.category),
                    detail: "Rule: \(rule.displayName) · \(path.risk.rawValue)",
                    recommended: path.defaultSelected || path.recommended
                )
            }
        }

        let associationTokens = associatedNameTokens(for: app)
        if let bundleID = app.bundleIdentifier {
            for root in [groupContainers, support, caches, logs, containers, httpStorages, webKit, applicationScripts] {
                for child in immediateChildren(of: root) {
                    let lower = child.lastPathComponent.lowercased()
                    if lower.contains(bundleID.lowercased()) || associationTokens.contains(where: { token in lower == token || lower.hasSuffix(".\(token)") }) {
                        appendIfExists(child, category: category(forLibraryRoot: root), detail: bundleID)
                    }
                }
            }
        }

        return items.sorted {
            if $0.category == $1.category { return $0.name < $1.name }
            return categorySortIndex($0.category) < categorySortIndex($1.category)
        }
    }

    static func scanStartupItems() -> [FileItem] {
        let roots: [(URL, String)] = [
            (fileURL("~/Library/LaunchAgents"), "User LaunchAgents"),
            (fileURL("/Library/LaunchAgents"), "Global LaunchAgents"),
            (fileURL("/Library/LaunchDaemons"), "Global LaunchDaemons"),
            (fileURL("/System/Library/LaunchAgents"), "System LaunchAgents"),
            (fileURL("/System/Library/LaunchDaemons"), "System LaunchDaemons")
        ]

        return roots.flatMap { root, detail in
            immediateChildren(of: root)
                .filter { $0.pathExtension.lowercased() == "plist" }
                .map {
                    let iconURL = startupIconURL(for: $0)
                    return FileItem(
                        url: $0,
                        category: .launchItem,
                    size: itemSize(of: $0, calculate: true),
                    modifiedAt: modificationDate(of: $0),
                    detail: startupDetail(for: $0, fallback: detail),
                    isRecommended: false,
                    isRemovable: true,
                    protectionReasons: protectionReasons(for: $0, category: .launchItem, size: itemSize(of: $0, calculate: false), app: nil, recommended: false),
                    iconURL: iconURL
                )
            }
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func scanExtensions() -> [FileItem] {
        let roots: [(URL, String)] = [
            (fileURL("~/Library/Safari/Extensions"), "Safari"),
            (fileURL("~/Library/Application Support/Google/Chrome/Default/Extensions"), "Chrome"),
            (fileURL("~/Library/Application Support/Microsoft Edge/Default/Extensions"), "Microsoft Edge"),
            (fileURL("~/Library/Application Support/Firefox/Profiles"), "Firefox Profiles"),
            (fileURL("~/Library/Internet Plug-Ins"), "User Internet Plug-Ins"),
            (fileURL("/Library/Internet Plug-Ins"), "Internet Plug-Ins"),
            (fileURL("~/Library/PreferencePanes"), "User PreferencePanes"),
            (fileURL("/Library/PreferencePanes"), "PreferencePanes"),
            (fileURL("~/Library/QuickLook"), "User QuickLook"),
            (fileURL("/Library/QuickLook"), "QuickLook"),
            (fileURL("~/Library/Spotlight"), "User Spotlight"),
            (fileURL("/Library/Spotlight"), "Spotlight"),
            (fileURL("~/Library/Audio/Plug-Ins"), "User Audio Plug-Ins"),
            (fileURL("/Library/Audio/Plug-Ins"), "Audio Plug-Ins"),
            (fileURL("/Library/Extensions"), "Kernel/System Extensions"),
            (fileURL("/System/Library/Extensions"), "System Extensions")
        ]

        return roots.flatMap { root, detail in
            immediateChildren(of: root).map {
                let metadata = extensionMetadata(for: $0, source: detail)
                let size = itemSize(of: $0, calculate: true)
                let reasons = protectionReasons(for: $0, category: .extensionItem, size: size, app: nil, recommended: false)
                return FileItem(
                    url: $0,
                    name: metadata.name ?? $0.lastPathComponent,
                    category: .extensionItem,
                    size: size,
                    modifiedAt: modificationDate(of: $0),
                    detail: metadata.detail,
                    isRecommended: false,
                    isRemovable: true,
                    protectionReasons: reasons
                )
            }
        }
        .sorted {
            if $0.detail == $1.detail { return $0.name < $1.name }
            return ($0.detail ?? "") < ($1.detail ?? "")
        }
    }

    static func scanLeftovers(installedApps: [InstalledApp]) -> [FileItem] {
        let installedIDs = Set(installedApps.compactMap(\.bundleIdentifier).map { $0.lowercased() })
        let roots: [(URL, FileCategory, String)] = [
            (fileURL("~/Library/Application Support"), .applicationSupport, "Application Support"),
            (fileURL("~/Library/Caches"), .cache, "Caches"),
            (fileURL("~/Library/Preferences"), .preferences, "Preferences"),
            (fileURL("~/Library/Containers"), .container, "Containers"),
            (fileURL("~/Library/HTTPStorages"), .cache, "HTTPStorages"),
            (fileURL("~/Library/WebKit"), .cache, "WebKit"),
            (fileURL("~/Library/Logs"), .logs, "Logs"),
            (fileURL("~/Library/Saved Application State"), .leftover, "Saved Application State")
        ]

        var seen = Set<String>()
        var items: [FileItem] = []

        for (root, category, detail) in roots {
            for child in immediateChildren(of: root) {
                let candidate = normalizedBundleIdentifier(from: child)
                guard looksLikeBundleIdentifier(candidate),
                      !candidate.hasPrefix("com.apple"),
                      !candidate.hasPrefix("com.local.maccleankit"),
                      !installedIDs.contains(candidate),
                      seen.insert(child.standardizedFileURL.path).inserted
                else { continue }

                let size = itemSize(of: child, calculate: true)
                let reasons = protectionReasons(for: child, category: category == .leftover ? .leftover : category, size: size, app: nil, recommended: false)
                items.append(
                    FileItem(
                        url: child,
                        category: category == .leftover ? .leftover : category,
                        size: size,
                        modifiedAt: modificationDate(of: child),
                        detail: detail,
                        isRecommended: false,
                        isRemovable: true,
                        protectionReasons: reasons
                    )
                )
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    static func scanCleanupItems() -> [FileItem] {
        var items: [FileItem] = []
        var seen = Set<String>()

        func append(_ url: URL, category: FileCategory, detail: String, recommended: Bool = false) {
            guard fm.fileExists(atPath: url.path), seen.insert(url.standardizedFileURL.path).inserted else { return }
            let size = itemSize(of: url, calculate: true)
            let reasons = protectionReasons(for: url, category: category, size: size, app: nil, recommended: recommended)
            items.append(
                FileItem(
                    url: url,
                    category: category,
                    size: size,
                    modifiedAt: modificationDate(of: url),
                    detail: detail,
                    isRecommended: recommended,
                    isRemovable: true,
                    protectionReasons: reasons
                )
            )
        }

        for child in immediateChildren(of: fileURL("~/Library/Caches")).prefix(120) {
            append(child, category: .cache, detail: "~/Library/Caches")
        }

        for child in immediateChildren(of: fileURL("~/Library/Logs")).prefix(120) {
            append(child, category: .logs, detail: "~/Library/Logs")
        }

        let downloads = fileURL("~/Downloads")
        let archiveExtensions: Set<String> = ["zip", "dmg", "pkg", "rar", "7z", "tar", "gz", "bz2", "xz", "iso"]
        for child in immediateChildren(of: downloads) {
            let ext = child.pathExtension.lowercased()
            if archiveExtensions.contains(ext) {
                append(child, category: .downloadArchive, detail: "~/Downloads", recommended: isOlderThan(child, days: 7))
            }

            let name = child.deletingPathExtension().lastPathComponent.lowercased()
            if name.contains("screenshot") || name.contains("屏幕快照") || name.contains("截屏") {
                append(child, category: .screenshot, detail: "~/Downloads", recommended: isOlderThan(child, days: 7))
            }
        }

        for child in immediateChildren(of: fileURL("~/Desktop")) {
            let name = child.deletingPathExtension().lastPathComponent.lowercased()
            if name.contains("screenshot") || name.contains("屏幕快照") || name.contains("截屏") {
                append(child, category: .screenshot, detail: "~/Desktop", recommended: isOlderThan(child, days: 7))
            }
        }

        let mailRoots = [
            fileURL("~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads"),
            fileURL("~/Library/Mail Downloads")
        ]
        for root in mailRoots {
            for child in immediateChildren(of: root) {
                append(child, category: .mailAttachment, detail: root.abbreviatedPath, recommended: isOlderThan(child, days: 14))
            }
        }

        append(fileURL("~/Library/Developer/Xcode/DerivedData"), category: .developerCache, detail: "Xcode DerivedData", recommended: true)
        append(fileURL("~/Library/Developer/Xcode/Archives"), category: .developerCache, detail: "Xcode Archives")
        append(fileURL("~/.Trash"), category: .trash, detail: "~/.Trash")

        return items.sorted { lhs, rhs in
            if lhs.category == rhs.category { return lhs.size > rhs.size }
            return categorySortIndex(lhs.category) < categorySortIndex(rhs.category)
        }
    }

    static func scanDiskUsage() -> [DiskUsageItem] {
        let home = fm.homeDirectoryForCurrentUser
        let urls = [
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Movies"),
            home.appendingPathComponent("Music"),
            home.appendingPathComponent("Pictures"),
            home.appendingPathComponent("Applications"),
            home.appendingPathComponent("Library"),
            fileURL("/Applications"),
            fileURL("/Users/Shared")
        ]

        return urls.filter { fm.fileExists(atPath: $0.path) }
            .map { DiskUsageItem(url: $0, size: itemSize(of: $0, calculate: true), modifiedAt: modificationDate(of: $0)) }
            .sorted { $0.size > $1.size }
    }

    static func scanDuplicates() -> [DuplicateGroup] {
        let roots = [
            fileURL("~/Downloads"),
            fileURL("~/Desktop"),
            fileURL("~/Documents")
        ].filter { fm.fileExists(atPath: $0.path) }

        var filesBySize: [Int64: [URL]] = [:]
        var visited = 0
        let maxFiles = 6_000

        for root in roots {
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isPackageKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let url as URL in enumerator {
                if Task.isCancelled { break }
                if visited >= maxFiles { break }

                let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isPackageKey, .fileSizeKey])
                if values?.isDirectory == true, values?.isPackage == true {
                    enumerator.skipDescendants()
                    continue
                }

                guard values?.isRegularFile == true,
                      let size = values?.fileSize,
                      size > 4_096,
                      size < 2_000_000_000
                else { continue }

                visited += 1
                filesBySize[Int64(size), default: []].append(url)
            }
        }

        var groups: [DuplicateGroup] = []

        for (size, urls) in filesBySize where urls.count > 1 {
            var bySampleHash: [String: [URL]] = [:]
            for url in urls {
                if Task.isCancelled { break }
                if let hash = sampleHash(of: url, size: size) {
                    bySampleHash[hash, default: []].append(url)
                }
            }

            for (_, candidates) in bySampleHash where candidates.count > 1 {
                var byFullHash: [String: [URL]] = [:]
                for url in candidates {
                    if Task.isCancelled { break }
                    if let hash = sha256(of: url) {
                        byFullHash[hash, default: []].append(url)
                    }
                }

                for (hash, duplicates) in byFullHash where duplicates.count > 1 {
                let files = duplicates
                    .sorted { (modificationDate(of: $0) ?? .distantPast) > (modificationDate(of: $1) ?? .distantPast) }
                    .map {
                        let reasons = protectionReasons(for: $0, category: .duplicate, size: size, app: nil, recommended: false)
                        return FileItem(
                            url: $0,
                            category: .duplicate,
                            size: size,
                            modifiedAt: modificationDate(of: $0),
                            detail: hash,
                            isRecommended: false,
                            isRemovable: true,
                            protectionReasons: reasons
                        )
                    }
                groups.append(DuplicateGroup(id: "\(hash)-\(size)", hash: hash, size: size, files: files))
                }
            }
        }

        return groups.sorted { $0.reclaimableSize > $1.reclaimableSize }
    }

    static func memoryStats() -> MemoryStats {
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return .empty
        }

        let page = Int64(pageSize)
        let free = Int64(stats.free_count + stats.speculative_count) * page
        let active = Int64(stats.active_count) * page
        let inactive = Int64(stats.inactive_count) * page
        let wired = Int64(stats.wire_count) * page
        let compressed = Int64(stats.compressor_page_count) * page
        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        let used = min(total, active + inactive + wired + compressed)

        return MemoryStats(total: total, used: used, free: free, inactive: inactive, wired: wired, compressed: compressed)
    }

    static func runPurge() -> Bool {
        let candidates = ["/usr/bin/purge", "/usr/sbin/purge"]
        guard let executable = candidates.first(where: { fm.isExecutableFile(atPath: $0) }) else { return false }
        let result = runProcess(executable, arguments: [], timeout: 5)
        return result.status == 0
    }

    static func buildUpdateCandidates(apps: [InstalledApp]) -> [UpdateCandidate] {
        let now = Date()
        return apps.map { app in
            let days: Int?
            if let modifiedAt = app.modifiedAt {
                days = Calendar.current.dateComponents([.day], from: modifiedAt, to: now).day
            } else {
                days = nil
            }

            let status: UpdateStatus
            if app.isAppStoreApp {
                status = .appStore
            } else if let days, days <= 45 {
                status = .recent
            } else if let days, days >= 240 {
                status = .stale
            } else {
                status = .manual
            }

            return UpdateCandidate(id: app.id, app: app, status: status, daysSinceModified: days)
        }
        .sorted {
            if $0.status.rawValue == $1.status.rawValue { return $0.app.name < $1.app.name }
            return updateSortIndex($0.status) < updateSortIndex($1.status)
        }
    }

    static func inspectSignature(for app: InstalledApp) -> SignatureReport {
        let verify = runProcess("/usr/bin/codesign", arguments: ["--verify", "--strict", "--verbose=2", app.url.path], timeout: 8)
        let assessment = runProcess("/usr/sbin/spctl", arguments: ["-a", "-vv", "-t", "execute", app.url.path], timeout: 8)

        let codeSignSummary: String
        if verify.status == 0 {
            codeSignSummary = verify.output.lines.first(where: { $0.localizedCaseInsensitiveContains("valid") }) ?? "valid on disk"
        } else {
            codeSignSummary = verify.output.trimmed.isEmpty ? "codesign verification failed" : verify.output.trimmed
        }

        let gatekeeperSummary: String
        if assessment.output.trimmed.isEmpty {
            gatekeeperSummary = assessment.status == 0 ? "accepted" : "not accepted"
        } else {
            gatekeeperSummary = assessment.output.lines.first ?? assessment.output.trimmed
        }

        return SignatureReport(codeSignSummary: codeSignSummary, gatekeeperSummary: gatekeeperSummary, isAccepted: assessment.status == 0)
    }

    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

private extension ScannerService {
    static func makeInstalledApp(from url: URL, calculateSize: Bool) -> InstalledApp? {
        let bundle = Bundle(url: url)
        let info = bundle?.infoDictionary ?? NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist")) as? [String: Any]
        let fallbackName = url.deletingPathExtension().lastPathComponent
        let name = (info?["CFBundleDisplayName"] as? String)
            ?? (info?["CFBundleName"] as? String)
            ?? fallbackName
        let bundleID = bundle?.bundleIdentifier ?? info?["CFBundleIdentifier"] as? String
        let version = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        let executableName = info?["CFBundleExecutable"] as? String
        let receipt = url.appendingPathComponent("Contents/_MASReceipt/receipt")
        let runningBundleIDs = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))

        return InstalledApp(
            id: url.standardizedFileURL.path,
            url: url,
            name: name,
            bundleIdentifier: bundleID,
            version: version,
            build: build,
            executableName: executableName,
            modifiedAt: modificationDate(of: url),
            size: calculateSize ? itemSize(of: url, calculate: true) : (cachedSize(for: url) ?? 0),
            isAppStoreApp: fm.fileExists(atPath: receipt.path),
            isAppleCoreApp: (bundleID?.hasPrefix("com.apple.") ?? false) || url.path.hasPrefix("/System/"),
            isRunning: bundleID.map { runningBundleIDs.contains($0) } ?? false,
            privacyUsageKeys: privacyUsageKeys(from: info ?? [:])
        )
    }

    static func itemSize(of url: URL, calculate: Bool) -> Int64 {
        if let cached = cachedSize(for: url) {
            return cached
        }
        return calculate ? allocatedSize(of: url) : 0
    }

    static func protectionReasons(
        for url: URL,
        category: FileCategory,
        size: Int64,
        app: InstalledApp?,
        recommended: Bool
    ) -> [ProtectionReason] {
        var reasons: [ProtectionReason] = []
        let path = url.standardizedFileURL.path
        reasons.append(contentsOf: PathSafety.protectionReasons(for: url))

        if path.hasPrefix("/System/") || path == "/System" {
            reasons.append(.systemPath)
        }

        if app?.isAppleCoreApp == true, category == .appBundle || app?.isAppleCoreApp == true && app?.isRunning == true {
            reasons.append(.appleCoreApp)
        }

        if app?.isRunning == true {
            reasons.append(.runningApplication)
        }

        if category == .appBundle, url.lastPathComponent.hasPrefix(".") {
            reasons.append(.protectedRule)
        }

        if isDirectory(url),
           size >= 20 * 1_024 * 1_024 * 1_024,
           !recommended,
           ![.cache, .logs, .developerCache, .trash, .downloadArchive, .screenshot, .mailAttachment, .duplicate].contains(category) {
            reasons.append(.unknownLargeDirectory)
        }

        return Array(Set(reasons))
    }

    static func isDirectory(_ url: URL) -> Bool {
        ((try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false) == true
    }

    static func extensionMetadata(for url: URL, source: String) -> (name: String?, detail: String) {
        let manifestURLs: [URL]
        if url.lastPathComponent == "Extensions" {
            manifestURLs = []
        } else {
            let direct = url.appendingPathComponent("manifest.json")
            let versionChildren = immediateChildren(of: url)
            manifestURLs = [direct] + versionChildren.map { $0.appendingPathComponent("manifest.json") }
        }

        for manifestURL in manifestURLs where fm.fileExists(atPath: manifestURL.path) {
            guard let data = try? Data(contentsOf: manifestURL),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            let rawName = json["name"] as? String
            let version = json["version"] as? String
            let normalizedName = rawName?.hasPrefix("__MSG_") == true ? url.lastPathComponent : rawName
            let pieces = [source, version.map { "v\($0)" }].compactMap { $0 }
            return (normalizedName, pieces.joined(separator: " · "))
        }

        return (nil, source)
    }

    static func privacyUsageKeys(from info: [String: Any]) -> [PrivacyUsage] {
        let mappings: [(String, PrivacyUsage)] = [
            ("NSCameraUsageDescription", .camera),
            ("NSMicrophoneUsageDescription", .microphone),
            ("NSLocationUsageDescription", .location),
            ("NSLocationWhenInUseUsageDescription", .location),
            ("NSContactsUsageDescription", .contacts),
            ("NSCalendarsUsageDescription", .calendars),
            ("NSRemindersUsageDescription", .reminders),
            ("NSPhotoLibraryUsageDescription", .photos),
            ("NSBluetoothAlwaysUsageDescription", .bluetooth),
            ("NSBluetoothPeripheralUsageDescription", .bluetooth),
            ("NSAppleEventsUsageDescription", .appleEvents),
            ("NSDesktopFolderUsageDescription", .userSelectedFiles),
            ("NSDocumentsFolderUsageDescription", .userSelectedFiles),
            ("NSDownloadsFolderUsageDescription", .userSelectedFiles),
            ("NSNetworkVolumesUsageDescription", .userSelectedFiles),
            ("NSRemovableVolumesUsageDescription", .userSelectedFiles)
        ]

        var seen = Set<PrivacyUsage>()
        return mappings.compactMap { key, usage in
            guard info[key] != nil, seen.insert(usage).inserted else { return nil }
            return usage
        }
    }

    static func candidateNames(for app: InstalledApp) -> [String] {
        var names = Set<String>()
        names.insert(app.name)
        names.insert(app.name.replacingOccurrences(of: " ", with: ""))
        if let executableName = app.executableName {
            names.insert(executableName)
        }
        if let bundleID = app.bundleIdentifier {
            names.insert(bundleID)
            names.insert(bundleID.components(separatedBy: ".").last ?? bundleID)
        }
        return names.filter { !$0.isEmpty }
    }

    static func associatedNameTokens(for app: InstalledApp) -> Set<String> {
        var tokens = Set<String>()
        let normalizedName = app.name.lowercased().replacingOccurrences(of: " ", with: "")
        if normalizedName.count >= 4 {
            tokens.insert(normalizedName)
        }
        if let executableName = app.executableName?.lowercased(), executableName.count >= 4 {
            tokens.insert(executableName)
        }
        if let bundleID = app.bundleIdentifier?.lowercased() {
            let parts = bundleID.split(separator: ".").map(String.init)
            for part in parts where part.count >= 5 && !["apple", "google", "microsoft"].contains(part) {
                tokens.insert(part)
            }
        }
        return tokens
    }

    static func expandRulePath(_ path: String, app: InstalledApp) -> URL {
        var expanded = path
            .replacingOccurrences(of: "${bundleIdentifier}", with: app.bundleIdentifier ?? "")
            .replacingOccurrences(of: "${appName}", with: app.name)
            .replacingOccurrences(of: "${executableName}", with: app.executableName ?? app.name)
        expanded = (expanded as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded).standardizedFileURL
    }

    static func startupDetail(for url: URL, fallback: String) -> String {
        guard let plist = NSDictionary(contentsOf: url) as? [String: Any] else {
            return fallback
        }

        let runtime = StartupManager.runtimeInfo(for: url)
        let label = plist["Label"] as? String
        let program = (plist["Program"] as? String)
            ?? (plist["ProgramArguments"] as? [String])?.first
        let runAtLoad = (plist["RunAtLoad"] as? Bool) == true ? "RunAtLoad" : nil
        let pieces = [fallback, runtime.status.rawValue, label, program, runAtLoad].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        return pieces.joined(separator: " · ")
    }

    static func startupIconURL(for url: URL) -> URL? {
        guard let plist = NSDictionary(contentsOf: url) as? [String: Any] else {
            return nil
        }

        let program = (plist["Program"] as? String)
            ?? (plist["ProgramArguments"] as? [String])?.first
        guard let program, !program.isEmpty else { return nil }

        let expanded = (program as NSString).expandingTildeInPath
        let programURL = URL(fileURLWithPath: expanded).standardizedFileURL
        guard fm.fileExists(atPath: programURL.path) else { return nil }

        if let appURL = containingAppBundle(for: programURL) {
            return appURL
        }
        return programURL
    }

    static func containingAppBundle(for url: URL) -> URL? {
        var current = url
        while current.path != "/" {
            if current.pathExtension.lowercased() == "app",
               fm.fileExists(atPath: current.path) {
                return current
            }
            current.deleteLastPathComponent()
        }
        return nil
    }

    static func category(forLibraryRoot root: URL) -> FileCategory {
        let name = root.lastPathComponent
        if name == "Application Support" { return .applicationSupport }
        if name == "Application Scripts" { return .applicationSupport }
        if name == "Caches" || name == "HTTPStorages" || name == "WebKit" { return .cache }
        if name == "Logs" { return .logs }
        if name == "Group Containers" { return .container }
        return .other
    }

    static func categorySortIndex(_ category: FileCategory) -> Int {
        switch category {
        case .appBundle: 0
        case .applicationSupport: 1
        case .container: 2
        case .cache: 3
        case .preferences: 4
        case .logs: 5
        case .launchItem: 6
        case .extensionItem: 7
        case .leftover: 8
        case .downloadArchive: 9
        case .screenshot: 10
        case .mailAttachment: 11
        case .developerCache: 12
        case .trash: 13
        case .duplicate: 14
        case .diskFolder: 15
        case .other: 16
        }
    }

    static func updateSortIndex(_ status: UpdateStatus) -> Int {
        switch status {
        case .stale: 0
        case .manual: 1
        case .appStore: 2
        case .recent: 3
        }
    }

    static func immediateChildren(of url: URL) -> [URL] {
        (try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []
    }

    static func modificationDate(of url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
    }

    static func isOlderThan(_ url: URL, days: Int) -> Bool {
        guard let modifiedAt = modificationDate(of: url),
              let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())
        else { return false }
        return modifiedAt < cutoff
    }

    static func normalizedBundleIdentifier(from url: URL) -> String {
        var name = url.lastPathComponent
        if name.hasSuffix(".plist") {
            name.removeLast(".plist".count)
        }
        if name.hasSuffix(".savedState") {
            name.removeLast(".savedState".count)
        }
        if name.hasSuffix(".binarycookies") {
            name.removeLast(".binarycookies".count)
        }
        return name.lowercased()
    }

    static func looksLikeBundleIdentifier(_ value: String) -> Bool {
        let parts = value.split(separator: ".")
        guard parts.count >= 3 else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-_.")
        return value.rangeOfCharacter(from: allowed.inverted) == nil
    }

    static func fileURL(_ path: String) -> URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
    }

    static func allocatedSize(of url: URL) -> Int64 {
        if let cached = cachedSize(for: url) {
            return cached
        }

        let computed: Int64
        if let duSize = allocatedSizeUsingDu(url) {
            computed = duSize
            cacheSize(computed, for: url)
            return computed
        }

        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey])
        if values?.isRegularFile == true {
            computed = Int64(values?.fileAllocatedSize ?? values?.totalFileAllocatedSize ?? 0)
            cacheSize(computed, for: url)
            return computed
        }

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let child as URL in enumerator {
            if Task.isCancelled { break }
            let values = try? child.resourceValues(forKeys: [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey])
            if values?.isRegularFile == true {
                total += Int64(values?.fileAllocatedSize ?? values?.totalFileAllocatedSize ?? 0)
            }
        }
        cacheSize(total, for: url)
        return total
    }

    static func cachedSize(for url: URL) -> Int64? {
        loadSizeCacheIfNeeded()
        let key = url.standardizedFileURL.path
        let modified = modificationDate(of: url)?.timeIntervalSince1970 ?? 0
        return sizeCacheQueue.sync {
            guard let entry = sizeCache[key], entry.modified == modified else { return nil }
            return entry.size
        }
    }

    static func cacheSize(_ size: Int64, for url: URL) {
        loadSizeCacheIfNeeded()
        let key = url.standardizedFileURL.path
        let modified = modificationDate(of: url)?.timeIntervalSince1970 ?? 0
        sizeCacheQueue.sync {
            sizeCache[key] = SizeCacheEntry(size: size, modified: modified)
            pendingSizeCacheWrites += 1
            if pendingSizeCacheWrites >= 50 {
                persistSizeCacheLocked()
                pendingSizeCacheWrites = 0
            }
        }
    }

    static func flushSizeCache() {
        loadSizeCacheIfNeeded()
        sizeCacheQueue.sync {
            guard pendingSizeCacheWrites > 0 else { return }
            persistSizeCacheLocked()
            pendingSizeCacheWrites = 0
        }
    }

    static func allocatedSizeUsingDu(_ url: URL) -> Int64? {
        let result = runProcess("/usr/bin/du", arguments: ["-sk", url.path])
        guard result.status == 0,
              let first = result.output.split(whereSeparator: \.isWhitespace).first,
              let kilobytes = Int64(first)
        else { return nil }
        return kilobytes * 1024
    }

    static func sha256(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            do {
                guard let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty else { break }
                hasher.update(data: data)
            } catch {
                return nil
            }
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func sampleHash(of url: URL, size: Int64) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        do {
            if let head = try handle.read(upToCount: 64 * 1024) {
                hasher.update(data: head)
            }
            if size > 128 * 1024 {
                try handle.seek(toOffset: UInt64(max(0, size - 64 * 1024)))
                if let tail = try handle.read(upToCount: 64 * 1024) {
                    hasher.update(data: tail)
                }
            }
            let sizeBytes = withUnsafeBytes(of: size.bigEndian, Array.init)
            hasher.update(data: Data(sizeBytes))
        } catch {
            return nil
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func runProcess(_ executable: String, arguments: [String], timeout: TimeInterval = 10) -> (output: String, status: Int32, timedOut: Bool) {
        let result = ProcessRunner.run(executable, arguments: arguments, timeout: timeout)
        return (result.output, result.status, result.timedOut)
    }

    static var sizeCacheURL: URL {
        AppConstants.applicationSupportDirectory.appendingPathComponent("size-cache.json")
    }

    static func loadSizeCacheIfNeeded() {
        sizeCacheQueue.sync {
            guard !didLoadSizeCache else { return }
            didLoadSizeCache = true
            guard let data = try? Data(contentsOf: sizeCacheURL),
                  let records = try? JSONDecoder.cleaner.decode([SizeCacheRecord].self, from: data)
            else { return }

            sizeCache = Dictionary(
                uniqueKeysWithValues: records.map { ($0.path, SizeCacheEntry(size: $0.size, modified: $0.modified)) }
            )
        }
    }

    static func persistSizeCacheLocked() {
        if sizeCache.count >= 10_000 {
            sizeCache = Dictionary(uniqueKeysWithValues: sizeCache.sorted { $0.key < $1.key }.prefix(8_000).map { ($0.key, $0.value) })
        }

        let records = sizeCache.map { path, entry in
            SizeCacheRecord(path: path, size: entry.size, modified: entry.modified)
        }
        guard let data = try? JSONEncoder.cleaner.encode(records) else { return }
        try? data.write(to: sizeCacheURL, options: [.atomic])
    }
}

private struct SizeCacheEntry: Sendable {
    let size: Int64
    let modified: TimeInterval
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var lines: [String] {
        split(whereSeparator: \.isNewline).map(String.init)
    }
}

private extension URL {
    var abbreviatedPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
