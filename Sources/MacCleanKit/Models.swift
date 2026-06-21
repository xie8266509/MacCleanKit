import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case zh
    case en

    var id: String { rawValue }

    var label: String {
        switch self {
        case .zh: "中文"
        case .en: "English"
        }
    }
}

enum CleanerSection: String, CaseIterable, Identifiable {
    case applications
    case startup
    case extensions
    case leftovers
    case cleanup
    case disk
    case duplicates
    case memory
    case updates
    case permissions

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .applications: "square.grid.2x2"
        case .startup: "power"
        case .extensions: "puzzlepiece.extension"
        case .leftovers: "doc.badge.gearshape"
        case .cleanup: "sparkles"
        case .disk: "chart.pie"
        case .duplicates: "doc.on.doc"
        case .memory: "memorychip"
        case .updates: "arrow.triangle.2.circlepath"
        case .permissions: "lock.shield"
        }
    }

    func title(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.applications, .zh): "应用程序"
        case (.applications, .en): "Applications"
        case (.startup, .zh): "启动程序"
        case (.startup, .en): "Startup"
        case (.extensions, .zh): "扩展"
        case (.extensions, .en): "Extensions"
        case (.leftovers, .zh): "残留文件"
        case (.leftovers, .en): "Leftovers"
        case (.cleanup, .zh): "清理"
        case (.cleanup, .en): "Cleanup"
        case (.disk, .zh): "磁盘分析"
        case (.disk, .en): "Disk Map"
        case (.duplicates, .zh): "重复文件"
        case (.duplicates, .en): "Duplicates"
        case (.memory, .zh): "内存"
        case (.memory, .en): "Memory"
        case (.updates, .zh): "更新"
        case (.updates, .en): "Updates"
        case (.permissions, .zh): "权限与日志"
        case (.permissions, .en): "Access & Logs"
        }
    }

    func subtitle(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.applications, .zh): "完整卸载和关联文件"
        case (.applications, .en): "Uninstall apps and support files"
        case (.startup, .zh): "LaunchAgents、Daemons"
        case (.startup, .en): "LaunchAgents and daemons"
        case (.extensions, .zh): "浏览器、插件、系统扩展"
        case (.extensions, .en): "Browser, plugin, system add-ons"
        case (.leftovers, .zh): "已删除应用留下的数据"
        case (.leftovers, .en): "Data left by removed apps"
        case (.cleanup, .zh): "缓存、日志、归档、截图"
        case (.cleanup, .en): "Caches, logs, archives, screenshots"
        case (.disk, .zh): "定位大文件夹"
        case (.disk, .en): "Find large folders"
        case (.duplicates, .zh): "按哈希查找重复内容"
        case (.duplicates, .en): "Hash-based duplicate scan"
        case (.memory, .zh): "内存压力和释放"
        case (.memory, .en): "Memory pressure and purge"
        case (.updates, .zh): "应用版本和更新线索"
        case (.updates, .en): "Versions and update hints"
        case (.permissions, .zh): "磁盘访问、操作日志、分发状态"
        case (.permissions, .en): "Disk access, operation logs, distribution status"
        }
    }
}

enum FileSort: String, CaseIterable, Identifiable {
    case category
    case name
    case size
    case date

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.category, .zh): "类型"
        case (.category, .en): "Kind"
        case (.name, .zh): "名称"
        case (.name, .en): "Name"
        case (.size, .zh): "大小"
        case (.size, .en): "Size"
        case (.date, .zh): "日期"
        case (.date, .en): "Date"
        }
    }
}

enum FileCategory: String, CaseIterable, Identifiable, Hashable {
    case appBundle
    case applicationSupport
    case cache
    case preferences
    case logs
    case container
    case launchItem
    case extensionItem
    case leftover
    case downloadArchive
    case screenshot
    case mailAttachment
    case developerCache
    case trash
    case duplicate
    case diskFolder
    case other

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .appBundle: "app"
        case .applicationSupport: "folder.badge.gearshape"
        case .cache: "shippingbox"
        case .preferences: "switch.2"
        case .logs: "doc.text.magnifyingglass"
        case .container: "cube.box"
        case .launchItem: "power"
        case .extensionItem: "puzzlepiece.extension"
        case .leftover: "doc.badge.gearshape"
        case .downloadArchive: "archivebox"
        case .screenshot: "camera.viewfinder"
        case .mailAttachment: "paperclip"
        case .developerCache: "hammer"
        case .trash: "trash"
        case .duplicate: "doc.on.doc"
        case .diskFolder: "folder"
        case .other: "doc"
        }
    }

    func title(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.appBundle, .zh): "应用本体"
        case (.appBundle, .en): "Application"
        case (.applicationSupport, .zh): "应用程序支持"
        case (.applicationSupport, .en): "Application Support"
        case (.cache, .zh): "缓存"
        case (.cache, .en): "Caches"
        case (.preferences, .zh): "偏好设置"
        case (.preferences, .en): "Preferences"
        case (.logs, .zh): "日志"
        case (.logs, .en): "Logs"
        case (.container, .zh): "容器"
        case (.container, .en): "Containers"
        case (.launchItem, .zh): "启动项"
        case (.launchItem, .en): "Launch Items"
        case (.extensionItem, .zh): "扩展"
        case (.extensionItem, .en): "Extensions"
        case (.leftover, .zh): "残留"
        case (.leftover, .en): "Leftovers"
        case (.downloadArchive, .zh): "下载归档"
        case (.downloadArchive, .en): "Download Archives"
        case (.screenshot, .zh): "截图"
        case (.screenshot, .en): "Screenshots"
        case (.mailAttachment, .zh): "邮件附件"
        case (.mailAttachment, .en): "Mail Attachments"
        case (.developerCache, .zh): "开发缓存"
        case (.developerCache, .en): "Developer Caches"
        case (.trash, .zh): "废纸篓"
        case (.trash, .en): "Trash"
        case (.duplicate, .zh): "重复项"
        case (.duplicate, .en): "Duplicates"
        case (.diskFolder, .zh): "文件夹"
        case (.diskFolder, .en): "Folder"
        case (.other, .zh): "其他"
        case (.other, .en): "Other"
        }
    }
}

enum FileScope: String, Sendable {
    case user
    case system

    func title(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.user, .zh): "用户位置"
        case (.user, .en): "User"
        case (.system, .zh): "系统位置"
        case (.system, .en): "System Area"
        }
    }
}

struct InstalledApp: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let name: String
    let bundleIdentifier: String?
    let version: String?
    let build: String?
    let executableName: String?
    let modifiedAt: Date?
    let size: Int64
    let isAppStoreApp: Bool
    let isAppleCoreApp: Bool
    let isRunning: Bool
    let privacyUsageKeys: [PrivacyUsage]

    var displayVersion: String {
        if let version, let build, build != version {
            return "\(version) (\(build))"
        }
        return version ?? build ?? "-"
    }

    func withSize(_ size: Int64) -> InstalledApp {
        InstalledApp(
            id: id,
            url: url,
            name: name,
            bundleIdentifier: bundleIdentifier,
            version: version,
            build: build,
            executableName: executableName,
            modifiedAt: modifiedAt,
            size: size,
            isAppStoreApp: isAppStoreApp,
            isAppleCoreApp: isAppleCoreApp,
            isRunning: isRunning,
            privacyUsageKeys: privacyUsageKeys
        )
    }
}

enum ProtectionReason: String, Codable, CaseIterable, Sendable {
    case systemPath
    case appleCoreApp
    case runningApplication
    case unknownLargeDirectory
    case protectedRule
    case protectedRoot
    case userContentRoot

    func title(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.systemPath, .zh): "系统路径"
        case (.systemPath, .en): "System Path"
        case (.appleCoreApp, .zh): "Apple 核心应用"
        case (.appleCoreApp, .en): "Apple Core App"
        case (.runningApplication, .zh): "正在运行"
        case (.runningApplication, .en): "Running"
        case (.unknownLargeDirectory, .zh): "未知大目录"
        case (.unknownLargeDirectory, .en): "Unknown Large Folder"
        case (.protectedRule, .zh): "规则保护"
        case (.protectedRule, .en): "Protected Rule"
        case (.protectedRoot, .zh): "受保护根目录"
        case (.protectedRoot, .en): "Protected Root"
        case (.userContentRoot, .zh): "用户内容根目录"
        case (.userContentRoot, .en): "User Content Root"
        }
    }
}

enum PrivacyUsage: String, CaseIterable, Identifiable, Sendable {
    case camera
    case microphone
    case location
    case contacts
    case calendars
    case reminders
    case photos
    case bluetooth
    case appleEvents
    case userSelectedFiles

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .camera: "camera"
        case .microphone: "mic"
        case .location: "location"
        case .contacts: "person.crop.circle"
        case .calendars: "calendar"
        case .reminders: "checklist"
        case .photos: "photo"
        case .bluetooth: "dot.radiowaves.left.and.right"
        case .appleEvents: "applescript"
        case .userSelectedFiles: "folder"
        }
    }

    func title(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.camera, .zh): "摄像头"
        case (.camera, .en): "Camera"
        case (.microphone, .zh): "麦克风"
        case (.microphone, .en): "Microphone"
        case (.location, .zh): "定位"
        case (.location, .en): "Location"
        case (.contacts, .zh): "通讯录"
        case (.contacts, .en): "Contacts"
        case (.calendars, .zh): "日历"
        case (.calendars, .en): "Calendars"
        case (.reminders, .zh): "提醒事项"
        case (.reminders, .en): "Reminders"
        case (.photos, .zh): "照片"
        case (.photos, .en): "Photos"
        case (.bluetooth, .zh): "蓝牙"
        case (.bluetooth, .en): "Bluetooth"
        case (.appleEvents, .zh): "自动化"
        case (.appleEvents, .en): "Automation"
        case (.userSelectedFiles, .zh): "文件访问"
        case (.userSelectedFiles, .en): "File Access"
        }
    }
}

struct FileItem: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let name: String
    let category: FileCategory
    let size: Int64
    let modifiedAt: Date?
    let detail: String?
    let isRecommended: Bool
    let isRemovable: Bool
    let protectionReasons: [ProtectionReason]
    let iconURL: URL?

    init(
        url: URL,
        name: String? = nil,
        category: FileCategory,
        size: Int64,
        modifiedAt: Date?,
        detail: String? = nil,
        isRecommended: Bool = false,
        isRemovable: Bool = true,
        protectionReasons: [ProtectionReason] = [],
        iconURL: URL? = nil
    ) {
        self.id = url.standardizedFileURL.path
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.category = category
        self.size = size
        self.modifiedAt = modifiedAt
        self.detail = detail
        self.isRecommended = isRecommended
        self.protectionReasons = protectionReasons
        self.isRemovable = isRemovable && protectionReasons.isEmpty
        self.iconURL = iconURL
    }

    var scope: FileScope {
        let path = url.standardizedFileURL.path
        if path.hasPrefix("/System/") || path.hasPrefix("/Library/") || path.hasPrefix("/Applications/") {
            return .system
        }
        return .user
    }
}

struct ScanProgress: Equatable, Sendable {
    var messageKey: String
    var detail: String
    var fraction: Double?

    static let idle = ScanProgress(messageKey: "last.message.ready", detail: "", fraction: nil)
}

enum PermissionStatus: String, Codable, Sendable {
    case available
    case limited
    case missing

    func title(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.available, .zh): "可访问"
        case (.available, .en): "Available"
        case (.limited, .zh): "受限"
        case (.limited, .en): "Limited"
        case (.missing, .zh): "不存在"
        case (.missing, .en): "Missing"
        }
    }
}

struct PermissionProbe: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let url: URL
    let status: PermissionStatus
    let detail: String
    let isImportant: Bool
}

enum StartupRuntimeStatus: String, Codable, Sendable {
    case loaded
    case notLoaded
    case unknown

    func title(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.loaded, .zh): "已加载"
        case (.loaded, .en): "Loaded"
        case (.notLoaded, .zh): "未加载"
        case (.notLoaded, .en): "Not Loaded"
        case (.unknown, .zh): "未知"
        case (.unknown, .en): "Unknown"
        }
    }
}

struct StartupRuntimeInfo: Hashable, Sendable {
    let label: String?
    let domain: String
    let status: StartupRuntimeStatus
    let detail: String
}

struct DuplicateGroup: Identifiable, Hashable, Sendable {
    let id: String
    let hash: String
    let size: Int64
    let files: [FileItem]

    var reclaimableSize: Int64 {
        guard files.count > 1 else { return 0 }
        return Int64(files.count - 1) * size
    }
}

enum DuplicateKeepPolicy: String, CaseIterable, Identifiable {
    case keepNewest
    case keepShortestPath
    case keepLargestFolder

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.keepNewest, .zh): "保留最新"
        case (.keepNewest, .en): "Keep Newest"
        case (.keepShortestPath, .zh): "保留最短路径"
        case (.keepShortestPath, .en): "Keep Shortest Path"
        case (.keepLargestFolder, .zh): "保留最大文件夹"
        case (.keepLargestFolder, .en): "Keep Largest Folder"
        }
    }
}

struct DiskUsageItem: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let name: String
    let size: Int64
    let modifiedAt: Date?

    init(url: URL, name: String? = nil, size: Int64, modifiedAt: Date?) {
        self.id = url.standardizedFileURL.path
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.size = size
        self.modifiedAt = modifiedAt
    }
}

struct MemoryStats: Equatable, Sendable {
    let total: Int64
    let used: Int64
    let free: Int64
    let inactive: Int64
    let wired: Int64
    let compressed: Int64

    static let empty = MemoryStats(total: 0, used: 0, free: 0, inactive: 0, wired: 0, compressed: 0)

    var pressure: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(used - inactive) / Double(total)))
    }
}

enum UpdateStatus: String, Sendable {
    case appStore
    case recent
    case stale
    case manual

    func title(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.appStore, .zh): "App Store 管理"
        case (.appStore, .en): "App Store managed"
        case (.recent, .zh): "近期更新"
        case (.recent, .en): "Recently updated"
        case (.stale, .zh): "建议检查"
        case (.stale, .en): "Check recommended"
        case (.manual, .zh): "手动检查"
        case (.manual, .en): "Manual check"
        }
    }
}

enum DistributionSigningStatus: String, Codable, Sendable {
    case developerID
    case adHoc
    case unsigned
    case unknown

    func title(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.developerID, .zh): "Developer ID"
        case (.developerID, .en): "Developer ID"
        case (.adHoc, .zh): "本地签名"
        case (.adHoc, .en): "Ad-hoc"
        case (.unsigned, .zh): "未签名"
        case (.unsigned, .en): "Unsigned"
        case (.unknown, .zh): "未知"
        case (.unknown, .en): "Unknown"
        }
    }
}

struct DistributionStatus: Codable, Equatable, Sendable {
    let appPath: String
    let bundleIdentifier: String
    let version: String
    let build: String
    let macOSVersion: String
    let signingStatus: DistributionSigningStatus
    let codesignSummary: String
    let gatekeeperSummary: String
    let isGatekeeperAccepted: Bool
    let isQuarantined: Bool
    let quarantineValue: String?

    static let unknown = DistributionStatus(
        appPath: "-",
        bundleIdentifier: AppConstants.bundleIdentifier,
        version: AppConstants.fallbackAppVersion,
        build: "-",
        macOSVersion: "-",
        signingStatus: .unknown,
        codesignSummary: "-",
        gatekeeperSummary: "-",
        isGatekeeperAccepted: false,
        isQuarantined: false,
        quarantineValue: nil
    )
}

struct UpdateCandidate: Identifiable, Hashable, Sendable {
    let id: String
    let app: InstalledApp
    let status: UpdateStatus
    let daysSinceModified: Int?
}

struct SignatureReport: Equatable, Sendable {
    let codeSignSummary: String
    let gatekeeperSummary: String
    let isAccepted: Bool

    static let empty = SignatureReport(codeSignSummary: "-", gatekeeperSummary: "-", isAccepted: false)
}

struct TrashLogItem: Codable, Hashable, Sendable {
    let path: String
    let name: String
    let category: String
    let size: Int64
}

struct TrashOperationLog: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let section: String
    let items: [TrashLogItem]
    let destination: String
    let succeeded: Bool
    let errorMessage: String?

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }
}

struct StartupBackup: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let originalPath: String
    let backupPath: String
    let name: String
    let date: Date
}

enum RuleRisk: String, Codable, Sendable {
    case safe
    case review
    case destructive
    case protected
}

struct RemovalRule: Codable, Hashable, Sendable {
    let bundleIdentifier: String
    let displayName: String
    let schemaVersion: Int
    let paths: [RulePath]
}

struct RulePath: Codable, Hashable, Sendable {
    let path: String
    let category: String
    let recommended: Bool
    let risk: RuleRisk
    let description: String
    let defaultSelected: Bool
}

struct SizeCacheRecord: Codable, Hashable, Sendable {
    let path: String
    let size: Int64
    let modified: TimeInterval
}

struct DiagnosticReport: Codable, Sendable {
    let appName: String
    let generatedAt: Date
    let appVersion: String
    let appBuild: String
    let bundleIdentifier: String
    let macOSVersion: String
    let distributionStatus: DistributionStatus
    let appUpdateInfo: AppUpdateInfo
    let permissionProbes: [DiagnosticPermissionProbe]
    let operationLogs: [TrashOperationLog]
    let startupBackups: [StartupBackup]
    let lastErrorMessage: String?
    let scanStatus: String
    let counts: [String: Int]
}

struct DiagnosticPermissionProbe: Codable, Sendable {
    let title: String
    let path: String
    let status: String
    let detail: String
    let isImportant: Bool
}

extension Int64 {
    var cleanerFileSize: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

extension DateFormatter {
    static let cleanerShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
