import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var store = CleanerStore()
    @State private var showTrashConfirmation = false

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(store: store)

            Divider()

            VStack(spacing: 0) {
                TopToolbar(store: store)
                Divider()

                Group {
                    switch store.selectedSection {
                    case .applications:
                        ApplicationManagerView(store: store) {
                            showTrashConfirmation = true
                        }
                    case .startup, .extensions, .leftovers, .cleanup:
                        FileModuleView(store: store) {
                            showTrashConfirmation = true
                        }
                    case .disk:
                        DiskAnalysisView(store: store)
                    case .duplicates:
                        DuplicateFinderView(store: store) {
                            showTrashConfirmation = true
                        }
                    case .memory:
                        MemoryView(store: store)
                    case .updates:
                        UpdatesView(store: store)
                    case .permissions:
                        PermissionsAndLogsView(store: store)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppTheme.windowBackground)
        .onAppear {
            store.startIfNeeded()
        }
        .sheet(isPresented: $showTrashConfirmation) {
            TrashConfirmationSheet(store: store) {
                showTrashConfirmation = false
            } confirmAction: {
                showTrashConfirmation = false
                store.moveSelectedToTrash()
            }
        }
        .sheet(isPresented: $store.showPermissionOnboarding) {
            PermissionOnboardingSheet(store: store)
        }
    }
}

private enum AppTheme {
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    static let elevatedPanel = Color(nsColor: .textBackgroundColor)
    static let inset = Color(nsColor: .textBackgroundColor)
    static let line = Color(nsColor: .separatorColor)
    static let primary = Color(nsColor: .controlAccentColor)
    static let accent = Color(nsColor: .systemGreen)
    static let amber = Color(nsColor: .systemOrange)
    static let danger = Color(nsColor: .systemRed)
    static let selectedRow = Color(nsColor: .selectedContentBackgroundColor)
    static let secondarySelectedRow = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
    static let controlFill = Color(nsColor: .controlColor)
    static let label = Color(nsColor: .labelColor)
    static let secondaryLabel = Color(nsColor: .secondaryLabelColor)
}

private struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }
}

private struct SidebarView: View {
    @ObservedObject var store: CleanerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                IconImageView(url: Bundle.main.bundleURL, size: 24, cornerRadius: 6)

                VStack(alignment: .leading, spacing: 1) {
                    Text("MacCleanKit")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("macOS")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

            ForEach(CleanerSection.allCases) { section in
                Button {
                    store.selectSection(section)
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: section.iconName)
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 18)
                        Text(section.title(store.language))
                            .font(.system(size: 13, weight: store.selectedSection == section ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Spacer(minLength: 0)
                        if section == .updates, store.appUpdateInfo.status == .available {
                            Circle()
                                .fill(store.selectedSection == section ? Color.white.opacity(0.86) : AppTheme.primary)
                                .frame(width: 7, height: 7)
                                .help(store.localizer("update.available.title"))
                        }
                    }
                    .foregroundStyle(store.selectedSection == section ? Color.white : AppTheme.label)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(store.selectedSection == section ? AppTheme.selectedRow : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .help(section.subtitle(store.language))
            }

            Spacer(minLength: 18)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 14)
        .frame(width: 186)
        .background(
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
    }
}

private struct TopToolbar: View {
    @ObservedObject var store: CleanerStore

    var body: some View {
        let l = store.localizer
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.selectedSection.title(store.language))
                    .font(.system(size: 24, weight: .semibold))
                Text(store.selectedSection.subtitle(store.language))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            if store.isScanning || store.isMoving {
                if let fraction = store.scanProgress.fraction {
                    ProgressView(value: fraction)
                        .frame(width: 86)
                        .controlSize(.small)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            StatusBadge(
                text: store.statusMessage,
                isBusy: store.isScanning || store.isMoving,
                isError: store.lastErrorMessage != nil
            )
            .frame(maxWidth: 250, alignment: .trailing)

            Picker("", selection: $store.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.label).tag(language)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 154)
            .controlSize(.small)

            Toggle(l("expert.mode"), isOn: $store.expertMode)
                .toggleStyle(.switch)
                .controlSize(.small)

            Button {
                store.refreshCurrentSection()
            } label: {
                Label(store.isScanning ? l("scanning") : l("scan"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(store.isScanning || store.isMoving)

            if store.isScanning {
                Button {
                    store.cancelScan()
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(l("cancel.scan"))
            }
        }
        .padding(.leading, 24)
        .padding(.trailing, 18)
        .padding(.vertical, 14)
        .background(
            VisualEffectBackground(material: .headerView, blendingMode: .withinWindow)
                .ignoresSafeArea()
        )
    }
}

private struct StatusBadge: View {
    let text: String
    let isBusy: Bool
    let isError: Bool

    private var color: Color {
        if isError { return AppTheme.danger }
        if isBusy { return AppTheme.primary }
        return AppTheme.accent
    }

    private var iconName: String {
        if isError { return "exclamationmark.triangle.fill" }
        if isBusy { return "arrow.triangle.2.circlepath" }
        return "checkmark.circle.fill"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(Capsule().fill(color.opacity(0.10)))
        .overlay(Capsule().stroke(color.opacity(0.20), lineWidth: 1))
    }
}

private enum AppSort: String, CaseIterable, Identifiable {
    case name
    case size
    case date

    var id: String { rawValue }

    func title(_ l: Localizer) -> String {
        switch self {
        case .name: l("sort.name")
        case .size: l("sort.size")
        case .date: l("sort.date")
        }
    }
}

private struct ApplicationManagerView: View {
    @ObservedObject var store: CleanerStore
    var trashAction: () -> Void
    @State private var searchText = ""
    @State private var sort: AppSort = .name

    private var filteredApps: [InstalledApp] {
        let searched = store.apps.filter { app in
            searchText.isEmpty
                || app.name.localizedCaseInsensitiveContains(searchText)
                || (app.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) ?? false)
        }

        switch sort {
        case .name:
            return searched.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .size:
            return searched.sorted { $0.size > $1.size }
        case .date:
            return searched.sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
        }
    }

    var body: some View {
        let l = store.localizer

        HStack(spacing: 0) {
            VStack(spacing: 12) {
                SearchField(text: $searchText, placeholder: l("search"))

                HStack(spacing: 10) {
                    Picker("", selection: $sort) {
                        ForEach(AppSort.allCases) { sort in
                            Text(sort.title(l)).tag(sort)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 224)

                    Spacer(minLength: 8)

                    Text("\(filteredApps.count) \(l("items"))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                ScrollView {
                    LazyVStack(spacing: 7) {
                        if filteredApps.isEmpty {
                            EmptyStateView(text: l("no.apps"), systemImage: "app.dashed")
                                .padding(.top, 40)
                        } else {
                            ForEach(filteredApps) { app in
                                AppListRow(
                                    app: app,
                                    language: store.language,
                                    isSelected: store.selectedAppID == app.id
                                ) {
                                    store.selectApp(app)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
            .padding(16)
            .frame(width: 384)
            .background(
                VisualEffectBackground(material: .contentBackground, blendingMode: .withinWindow)
                    .ignoresSafeArea()
            )

            Divider()

            if let app = store.selectedApp {
                AppDetailView(store: store, app: app, trashAction: trashAction)
            } else {
                EmptyStateView(text: l("app.detail.hint"), systemImage: "app.badge")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 34)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AppTheme.elevatedPanel.opacity(0.88)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.line.opacity(0.42), lineWidth: 1))
    }
}

private struct AppListRow: View {
    let app: InstalledApp
    let language: AppLanguage
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        let l = Localizer(language: language)

        Button(action: action) {
            HStack(spacing: 12) {
                AppIconView(url: app.url, size: 36)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(app.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isSelected ? Color.white : AppTheme.label)
                            .lineLimit(1)
                        if app.isAppleCoreApp {
                            Image(systemName: "desktopcomputer")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.white.opacity(0.72) : AppTheme.secondaryLabel.opacity(0.70))
                                .help(l("system.app"))
                        }
                    }
                    Text(app.modifiedAt.map { DateFormatter.cleanerShort.string(from: $0) } ?? "-")
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.72) : AppTheme.secondaryLabel)
                }

                Spacer(minLength: 8)

                Text(app.size > 0 ? app.size.cleanerFileSize : "…")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.82) : AppTheme.secondaryLabel)
            }
            .padding(.horizontal, 12)
            .frame(height: 54)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? AppTheme.selectedRow : AppTheme.elevatedPanel.opacity(0.76))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.clear : AppTheme.line.opacity(0.42), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AppDetailView: View {
    @ObservedObject var store: CleanerStore
    let app: InstalledApp
    var trashAction: () -> Void
    @State private var fileSort: FileSort = .category

    var body: some View {
        let l = store.localizer
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    AppDetailHeader(store: store, app: app)

                    DetailSummaryStrip(
                        itemCount: store.associatedFiles.count,
                        selectedCount: store.selectedTrashItems.count,
                        selectedSize: store.selectedTrashSize,
                        language: store.language
                    )

                    InfoBanner(
                        icon: "lock.shield",
                        text: "\(l("permission.note")) \(l("safe.mode"))",
                        color: AppTheme.accent
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Picker(l("file.sort"), selection: $fileSort) {
                                ForEach(FileSort.allCases) { sort in
                                    Text(sort.title(store.language)).tag(sort)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 280)
                            Spacer()
                        }

                        ActionStrip(store: store, trashAction: trashAction)
                            .frame(maxWidth: 520, alignment: .leading)
                    }

                    FileGroupList(items: store.associatedFiles, sort: fileSort, store: store)
                }
                .padding(18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.windowBackground)
    }
}

private struct DetailSummaryStrip: View {
    let itemCount: Int
    let selectedCount: Int
    let selectedSize: Int64
    let language: AppLanguage

    var body: some View {
        let l = Localizer(language: language)
        HStack(spacing: 10) {
            SummaryTile(
                title: l("associated.files"),
                value: "\(itemCount)",
                systemImage: "folder.badge.gearshape",
                color: AppTheme.primary
            )
            SummaryTile(
                title: l("selected"),
                value: "\(selectedCount)",
                systemImage: "checkmark.square",
                color: AppTheme.accent
            )
            SummaryTile(
                title: l("reclaimable"),
                value: selectedSize.cleanerFileSize,
                systemImage: "trash",
                color: selectedCount > 0 ? AppTheme.danger : AppTheme.secondaryLabel
            )
        }
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .background(Circle().fill(color.opacity(0.10)))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AppTheme.elevatedPanel))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.line.opacity(0.45), lineWidth: 1))
    }
}

private struct AppDetailHeader: View {
    @ObservedObject var store: CleanerStore
    let app: InstalledApp

    var body: some View {
        let l = store.localizer

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                AppIconView(url: app.url, size: 58)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(app.name)
                            .font(.system(size: 22, weight: .semibold))
                            .lineLimit(1)
                        if app.isAppleCoreApp {
                            Chip(label: l("system.app"), systemImage: "desktopcomputer", color: AppTheme.amber)
                        }
                        Spacer()
                        Text(app.size > 0 ? app.size.cleanerFileSize : "…")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.primary)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], alignment: .leading, spacing: 8) {
                        MetadataLine(label: l("version"), value: app.displayVersion)
                        MetadataLine(label: l("bundle.id"), value: app.bundleIdentifier ?? "-")
                        MetadataLine(label: l("modified"), value: app.modifiedAt.map { DateFormatter.cleanerShort.string(from: $0) } ?? "-")
                        MetadataLine(label: l("app.store"), value: app.isAppStoreApp ? "Yes" : "No")
                    }

                    Text(app.url.abbreviatedPath)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Divider()

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionCaption(title: l("privacy"), systemImage: "hand.raised")
                    if app.privacyUsageKeys.isEmpty {
                        Text(l("no.privacy"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        FlowLayout(spacing: 8) {
                            ForEach(app.privacyUsageKeys) { usage in
                                Chip(label: usage.title(store.language), systemImage: usage.iconName, color: AppTheme.primary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    SectionCaption(title: l("security"), systemImage: "checkmark.shield")
                    MetadataLine(label: l("security"), value: store.signatureReport?.codeSignSummary ?? "-")
                    MetadataLine(label: l("gatekeeper"), value: store.signatureReport?.gatekeeperSummary ?? "-")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .panelStyle()
    }
}

private struct FileModuleView: View {
    @ObservedObject var store: CleanerStore
    var trashAction: () -> Void
    @State private var fileSort: FileSort = .category

    var body: some View {
        let l = store.localizer
        let items = store.itemsForSection(store.selectedSection)

        VStack(alignment: .leading, spacing: 14) {
            InfoBanner(icon: warningIcon, text: warningText(l), color: warningColor)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    MetricPill(title: l("items"), value: "\(items.count)", systemImage: "list.bullet.rectangle")
                    MetricPill(title: l("total"), value: items.reduce(0) { $0 + $1.size }.cleanerFileSize, systemImage: "internaldrive")
                    Spacer()
                }

                HStack {
                    Picker(l("file.sort"), selection: $fileSort) {
                        ForEach(FileSort.allCases) { sort in
                            Text(sort.title(store.language)).tag(sort)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 260)

                    if store.selectedSection == .startup {
                        Button {
                            store.disableSelectedStartupItems()
                        } label: {
                            Label(l("disable.startup"), systemImage: "pause.circle")
                        }
                        .disabled(store.selectedTrashItems.filter { $0.category == .launchItem }.isEmpty)
                    }

                    Spacer(minLength: 10)
                    ActionStrip(store: store, trashAction: trashAction)
                        .frame(maxWidth: 520, alignment: .trailing)
                }
            }

            ScrollView {
                FileGroupList(items: items, sort: fileSort, store: store)
            }
            .scrollSurfaceStyle()
        }
        .padding(18)
    }

    private var warningIcon: String {
        switch store.selectedSection {
        case .startup: "power"
        case .extensions: "puzzlepiece.extension"
        case .leftovers: "exclamationmark.triangle"
        case .cleanup: "sparkles"
        default: "info.circle"
        }
    }

    private var warningColor: Color {
        store.selectedSection == .leftovers ? AppTheme.amber : AppTheme.accent
    }

    private func warningText(_ l: Localizer) -> String {
        switch store.selectedSection {
        case .startup: l("startup.warning")
        case .extensions: l("extensions.warning")
        case .leftovers: l("leftover.warning")
        case .cleanup: l("cleanup.warning")
        default: ""
        }
    }
}

private struct DuplicateFinderView: View {
    @ObservedObject var store: CleanerStore
    var trashAction: () -> Void
    @State private var keepPolicy: DuplicateKeepPolicy = .keepNewest

    var body: some View {
        let l = store.localizer
        VStack(alignment: .leading, spacing: 14) {
            InfoBanner(icon: "doc.on.doc", text: l("duplicates.warning"), color: AppTheme.accent)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    MetricPill(title: l("duplicate.group"), value: "\(store.duplicateGroups.count)", systemImage: "doc.on.doc")
                    MetricPill(title: l("reclaimable"), value: store.duplicateGroups.reduce(0) { $0 + $1.reclaimableSize }.cleanerFileSize, systemImage: "trash")
                    Spacer()
                }

                HStack {
                    Picker(l("duplicate.policy"), selection: $keepPolicy) {
                        ForEach(DuplicateKeepPolicy.allCases) { policy in
                            Text(policy.title(store.language)).tag(policy)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 310)

                    Button {
                        store.autoSelectDuplicates(policy: keepPolicy)
                    } label: {
                        Label(l("auto.select"), systemImage: "checkmark.circle")
                    }
                    .disabled(store.duplicateGroups.isEmpty)

                    Button {
                        store.scanSection(.duplicates, force: true)
                    } label: {
                        Label(l("scan.duplicates"), systemImage: "magnifyingglass")
                    }
                    .disabled(store.isScanning)

                    Spacer(minLength: 10)
                    ActionStrip(store: store, trashAction: trashAction)
                        .frame(maxWidth: 520, alignment: .trailing)
                }
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    if store.duplicateGroups.isEmpty {
                        EmptyStateView(text: l("no.files"), systemImage: "doc.on.doc")
                            .padding(.top, 80)
                    } else {
                        ForEach(store.duplicateGroups) { group in
                            DuplicateGroupView(group: group, store: store)
                        }
                    }
                }
                .padding(14)
            }
            .scrollSurfaceStyle()
        }
        .padding(18)
    }
}

private struct DuplicateGroupView: View {
    let group: DuplicateGroup
    @ObservedObject var store: CleanerStore

    var body: some View {
        let l = store.localizer
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "number.square")
                    .foregroundStyle(AppTheme.primary)
                Text("\(l("duplicate.group")) · \(group.files.count) \(l("items"))")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(group.reclaimableSize.cleanerFileSize)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)

            ForEach(group.files) { item in
                FileRow(item: item, store: store)
            }
        }
        .padding(.bottom, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.inset))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line.opacity(0.55), lineWidth: 1))
    }
}

private struct DiskAnalysisView: View {
    @ObservedObject var store: CleanerStore

    var body: some View {
        let l = store.localizer
        let total = max(1, store.diskItems.map(\.size).max() ?? 1)

        VStack(alignment: .leading, spacing: 14) {
            InfoBanner(icon: "chart.pie", text: l("disk.warning"), color: AppTheme.accent)

            HStack {
                MetricPill(title: l("largest.locations"), value: "\(store.diskItems.count)", systemImage: "folder")
                MetricPill(title: l("total"), value: store.diskItems.reduce(0) { $0 + $1.size }.cleanerFileSize, systemImage: "internaldrive")
                Spacer()
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    if store.diskItems.isEmpty {
                        EmptyStateView(text: l("no.files"), systemImage: "chart.pie")
                            .padding(.top, 80)
                    } else {
                        ForEach(store.diskItems) { item in
                            DiskUsageRow(item: item, maxSize: total, store: store)
                        }
                    }
                }
                .padding(14)
            }
            .scrollSurfaceStyle()
        }
        .padding(18)
    }
}

private struct DiskUsageRow: View {
    let item: DiskUsageItem
    let maxSize: Int64
    @ObservedObject var store: CleanerStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    Text(item.size.cleanerFileSize)
                        .font(.system(size: 12, weight: .semibold))
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppTheme.line.opacity(0.35))
                        Capsule()
                            .fill(AppTheme.primary.opacity(0.75))
                            .frame(width: max(6, proxy.size.width * CGFloat(Double(item.size) / Double(maxSize))))
                    }
                }
                .frame(height: 6)

                Text(item.url.abbreviatedPath)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Button {
                store.reveal(item.url)
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help(store.localizer("open.finder"))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.inset))
    }
}

private struct MemoryView: View {
    @ObservedObject var store: CleanerStore

    var body: some View {
        let l = store.localizer
        let stats = store.memoryStats

        VStack(alignment: .leading, spacing: 14) {
            InfoBanner(icon: "memorychip", text: l("memory.warning"), color: AppTheme.accent)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionCaption(title: l("memory.pressure"), systemImage: "gauge.with.dots.needle.50percent")
                    Spacer()
                    Text("\(Int(stats.pressure * 100))%")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(stats.pressure > 0.82 ? AppTheme.danger : AppTheme.primary)
                }
                ProgressView(value: stats.pressure)
                    .progressViewStyle(.linear)
                    .tint(stats.pressure > 0.82 ? AppTheme.danger : AppTheme.primary)
            }
            .panelStyle()

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
                MetricCard(title: l("total"), value: stats.total.cleanerFileSize, systemImage: "memorychip")
                MetricCard(title: l("used.memory"), value: stats.used.cleanerFileSize, systemImage: "chart.bar.fill")
                MetricCard(title: l("free.memory"), value: stats.free.cleanerFileSize, systemImage: "checkmark.circle")
                MetricCard(title: l("inactive.memory"), value: stats.inactive.cleanerFileSize, systemImage: "pause.circle")
                MetricCard(title: l("wired.memory"), value: stats.wired.cleanerFileSize, systemImage: "bolt.horizontal")
                MetricCard(title: l("compressed.memory"), value: stats.compressed.cleanerFileSize, systemImage: "arrow.down.left.and.arrow.up.right")
            }

            HStack {
                Spacer()
                Button {
                    store.purgeMemory()
                } label: {
                    Label(l("purge.memory"), systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isScanning)
            }

            Spacer()
        }
        .padding(18)
    }
}

private struct UpdatesView: View {
    @ObservedObject var store: CleanerStore

    var body: some View {
        let l = store.localizer
        VStack(alignment: .leading, spacing: 14) {
            AppUpdateCard(store: store)
            InfoBanner(icon: "arrow.triangle.2.circlepath", text: l("updates.warning"), color: AppTheme.accent)

            HStack {
                MetricPill(title: l("items"), value: "\(store.updateItems.count)", systemImage: "app")
                MetricPill(
                    title: l("recommended"),
                    value: "\(store.updateItems.filter { $0.status == .stale }.count)",
                    systemImage: "exclamationmark.triangle"
                )
                Spacer()
                Button {
                    store.openAppStoreUpdates()
                } label: {
                    Label(l("open.appstore.updates"), systemImage: "bag")
                }
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    if store.updateItems.isEmpty {
                        EmptyStateView(text: l("no.files"), systemImage: "arrow.triangle.2.circlepath")
                            .padding(.top, 80)
                    } else {
                        ForEach(store.updateItems) { candidate in
                            UpdateRow(candidate: candidate, store: store)
                        }
                    }
                }
                .padding(14)
            }
            .scrollSurfaceStyle()
        }
        .padding(18)
    }
}

private struct AppUpdateCard: View {
    @ObservedObject var store: CleanerStore

    var body: some View {
        let info = store.appUpdateInfo
        let l = store.localizer
        let color = statusColor(info.status)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: statusIcon(info.status))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(color.opacity(0.10)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(statusTitle(info.status, l: l))
                        .font(.system(size: 14, weight: .semibold))
                    Text(statusBody(info, l: l))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                if info.status == .checking || store.isCheckingAppUpdate {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    store.checkForAppUpdate(userInitiated: true)
                } label: {
                    Label(l("check.updates"), systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
                .disabled(store.isCheckingAppUpdate)

                if info.status == .available {
                    Button {
                        store.openAppUpdateDownload()
                    } label: {
                        Label(l("download.update"), systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else {
                    Button {
                        store.openAppUpdateRelease()
                    } label: {
                        Label(l("open.releases"), systemImage: "safari")
                    }
                    .controlSize(.small)
                }
            }

            HStack(spacing: 10) {
                VersionPill(title: l("current.version"), value: info.currentVersion, systemImage: "macwindow")
                VersionPill(title: l("latest.version"), value: info.latestVersion ?? "-", systemImage: "tag")
                if let checkedAt = info.checkedAt {
                    VersionPill(title: l("last.checked"), value: DateFormatter.cleanerShort.string(from: checkedAt), systemImage: "clock")
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AppTheme.elevatedPanel))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(color.opacity(0.22), lineWidth: 1))
    }

    private func statusColor(_ status: AppUpdateCheckStatus) -> Color {
        switch status {
        case .available: AppTheme.primary
        case .current, .sparkleManaged: AppTheme.accent
        case .failed: AppTheme.danger
        case .checking: AppTheme.primary
        case .idle: AppTheme.secondaryLabel
        }
    }

    private func statusIcon(_ status: AppUpdateCheckStatus) -> String {
        switch status {
        case .available: "arrow.down.circle.fill"
        case .current: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .checking: "arrow.triangle.2.circlepath"
        case .sparkleManaged: "sparkles"
        case .idle: "clock"
        }
    }

    private func statusTitle(_ status: AppUpdateCheckStatus, l: Localizer) -> String {
        switch status {
        case .available: l("update.available.title")
        case .current: l("update.current.title")
        case .failed: l("update.failed.title")
        case .checking: l("update.checking.title")
        case .sparkleManaged: l("update.sparkle.title")
        case .idle: l("update.idle.title")
        }
    }

    private func statusBody(_ info: AppUpdateInfo, l: Localizer) -> String {
        switch info.status {
        case .available:
            let latest = info.latestVersion ?? "-"
            return "\(l("update.available.body")) \(latest)"
        case .current:
            return l("update.current.body")
        case .failed:
            return info.message ?? l("update.failed.body")
        case .checking:
            return l("update.checking.body")
        case .sparkleManaged:
            return l("update.sparkle.body")
        case .idle:
            return l("update.idle.body")
        }
    }
}

private struct VersionPill: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(Capsule().fill(AppTheme.controlFill.opacity(0.35)))
        .overlay(Capsule().stroke(AppTheme.line.opacity(0.35), lineWidth: 1))
    }
}

private struct UpdateRow: View {
    let candidate: UpdateCandidate
    @ObservedObject var store: CleanerStore

    var body: some View {
        let l = store.localizer
        HStack(spacing: 12) {
            AppIconView(url: candidate.app.url, size: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.app.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text("\(l("version")) \(candidate.app.displayVersion)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Chip(
                label: candidate.status.title(store.language),
                systemImage: candidate.status == .stale ? "exclamationmark.triangle" : "checkmark.circle",
                color: candidate.status == .stale ? AppTheme.amber : AppTheme.accent
            )

            Text(candidate.daysSinceModified.map { "\($0)d" } ?? "-")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .trailing)

            Button {
                store.reveal(candidate.app.url)
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.inset))
    }
}

private struct PermissionsAndLogsView: View {
    @ObservedObject var store: CleanerStore

    var body: some View {
        let l = store.localizer

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                InfoBanner(icon: "lock.shield", text: l("full.disk.access.hint"), color: AppTheme.amber)
                PermissionSummaryView(store: store)

                HStack {
                    Button {
                        store.refreshPermissionProbes()
                    } label: {
                        Label(l("refresh.permissions"), systemImage: "arrow.clockwise")
                    }

                    Button {
                        store.openFullDiskAccessSettings()
                    } label: {
                        Label(l("open.full.disk.access"), systemImage: "gearshape")
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    Button {
                        store.openSupportFolder()
                    } label: {
                        Label(l("open.support.folder"), systemImage: "folder")
                    }

                    Button {
                        store.exportDiagnostics()
                    } label: {
                        Label(l("export.diagnostics"), systemImage: "square.and.arrow.up")
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionCaption(title: l("permissions"), systemImage: "lock.shield")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 10)], spacing: 10) {
                        ForEach(store.permissionProbes) { probe in
                            PermissionProbeCard(probe: probe, language: store.language)
                        }
                    }
                }
                .panelStyle()

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SectionCaption(title: l("operation.log"), systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Button(l("clear.log")) {
                            store.clearOperationLogs()
                        }
                        .disabled(store.operationLogs.isEmpty)
                    }

                    if store.operationLogs.isEmpty {
                        EmptyStateView(text: l("no.files"), systemImage: "clock")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(store.operationLogs.prefix(10)) { log in
                            OperationLogRow(log: log, language: store.language)
                        }
                    }
                }
                .panelStyle()

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SectionCaption(title: l("disabled.startup"), systemImage: "pause.circle")
                        Spacer()
                        Button {
                            store.restoreStartupBackups(store.startupBackups)
                        } label: {
                            Label(l("restore.startup"), systemImage: "arrow.uturn.backward")
                        }
                        .disabled(store.startupBackups.isEmpty)
                    }

                    if store.startupBackups.isEmpty {
                        EmptyStateView(text: l("no.files"), systemImage: "power")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(store.startupBackups.prefix(10)) { backup in
                            HStack(spacing: 10) {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(AppTheme.primary)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(backup.name)
                                        .font(.system(size: 12, weight: .medium))
                                    Text(backup.originalPath)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Text(DateFormatter.cleanerShort.string(from: backup.date))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.inset))
                        }
                    }
                }
                .panelStyle()

                HStack(alignment: .top, spacing: 12) {
                    MetricCard(title: l("rules"), value: "\(RuleStore.loadRules().count)", systemImage: "list.bullet.clipboard")
                    VStack(alignment: .leading, spacing: 8) {
                        SectionCaption(title: l("distribution"), systemImage: "shippingbox")
                        Text(l("distribution.hint"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .panelStyle()
                }
            }
            .padding(18)
        }
    }
}

private struct PermissionSummaryView: View {
    @ObservedObject var store: CleanerStore

    var body: some View {
        let l = store.localizer
        let available = store.permissionProbes.filter { $0.status == .available }.count
        let limited = store.permissionProbes.filter { $0.status == .limited }.count
        let missing = store.permissionProbes.filter { $0.status == .missing }.count
        let importantLimited = store.permissionProbes.filter { $0.isImportant && $0.status == .limited }.count

        HStack(spacing: 10) {
            MetricPill(title: l("available"), value: "\(available)", systemImage: "checkmark.circle")
            MetricPill(title: l("limited"), value: "\(limited)", systemImage: "exclamationmark.triangle")
            MetricPill(title: l("missing"), value: "\(missing)", systemImage: "questionmark.circle")
            MetricPill(title: l("important"), value: "\(importantLimited)", systemImage: "star.fill")
            Spacer()
        }
    }
}

private struct PermissionProbeCard: View {
    let probe: PermissionProbe
    let language: AppLanguage

    var body: some View {
        let color: Color = switch probe.status {
        case .available: AppTheme.accent
        case .limited: AppTheme.amber
        case .missing: .secondary
        }

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Chip(
                    label: probe.status.title(language),
                    systemImage: probe.status == .available ? "checkmark.circle" : "exclamationmark.triangle",
                    color: color
                )
                Spacer()
                if probe.isImportant {
                    Image(systemName: "star.fill")
                        .foregroundStyle(AppTheme.amber)
                        .font(.system(size: 11))
                }
            }
            Text(probe.title)
                .font(.system(size: 13, weight: .semibold))
            Text(probe.url.abbreviatedPath)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(probe.detail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.inset))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.22), lineWidth: 1))
    }
}

private struct OperationLogRow: View {
    let log: TrashOperationLog
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: log.succeeded ? "trash" : "exclamationmark.triangle")
                .foregroundStyle(log.succeeded ? AppTheme.accent : AppTheme.danger)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(log.items.count) items · \(log.totalSize.cleanerFileSize)")
                    .font(.system(size: 12, weight: .semibold))
                Text(log.items.prefix(3).map(\.name).joined(separator: ", "))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(DateFormatter.cleanerShort.string(from: log.date))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.inset))
    }
}

private struct TrashConfirmationSheet: View {
    @ObservedObject var store: CleanerStore
    var cancelAction: () -> Void
    var confirmAction: () -> Void

    var body: some View {
        let l = store.localizer
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionCaption(title: l("trash.confirm.review"), systemImage: "trash")
                Spacer()
                Text("\(store.selectedTrashItems.count) · \(store.selectedTrashSize.cleanerFileSize)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            InfoBanner(icon: "exclamationmark.triangle", text: l("confirm.message"), color: AppTheme.amber)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(store.selectedTrashItems) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.category.iconName)
                                .foregroundStyle(AppTheme.primary)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name)
                                    .font(.system(size: 12, weight: .medium))
                                Text(item.url.abbreviatedPath)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Text(item.size.cleanerFileSize)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.inset))
                    }
                }
            }
            .frame(minHeight: 240, maxHeight: 360)

            HStack {
                Spacer()
                Button(l("cancel"), action: cancelAction)
                    .keyboardShortcut(.cancelAction)
                Button(role: .destructive, action: confirmAction) {
                    Label(l("move.trash"), systemImage: "trash")
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 680)
    }
}

private struct PermissionOnboardingSheet: View {
    @ObservedObject var store: CleanerStore

    var body: some View {
        let l = store.localizer
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(l("permission.onboarding.title"))
                        .font(.system(size: 22, weight: .semibold))
                    Text(l("permission.onboarding.body"))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            LazyVStack(spacing: 8) {
                ForEach(store.permissionProbes.filter(\.isImportant)) { probe in
                    PermissionProbeCard(probe: probe, language: store.language)
                }
            }

            HStack {
                Button(l("skip")) {
                    store.completePermissionOnboarding()
                }
                Spacer()
                Button(l("retest")) {
                    store.refreshPermissionProbes()
                }
                Button {
                    store.openFullDiskAccessSettings()
                } label: {
                    Label(l("open.full.disk.access"), systemImage: "gearshape")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 640)
    }
}

private struct ActionStrip: View {
    @ObservedObject var store: CleanerStore
    var trashAction: () -> Void

    var body: some View {
        let l = store.localizer
        HStack(spacing: 8) {
            Button {
                store.selectAllCurrentItems()
            } label: {
                Label(l("select.all"), systemImage: "checkmark.square")
            }
            .buttonStyle(.bordered)

            Button {
                store.clearSelection()
            } label: {
                Label(l("clear"), systemImage: "xmark.square")
            }
            .buttonStyle(.bordered)

            Button {
                trashAction()
            } label: {
                Label(l("move.trash"), systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.danger)
            .disabled(store.selectedTrashItems.isEmpty || store.isMoving)

            Text("\(store.selectedTrashItems.count) · \(store.selectedTrashSize.cleanerFileSize)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(minWidth: 76, alignment: .trailing)
        }
        .controlSize(.small)
    }
}

private struct FileGroupList: View {
    let items: [FileItem]
    let sort: FileSort
    @ObservedObject var store: CleanerStore
    @State private var collapsedCategories: Set<FileCategory> = []

    var body: some View {
        let l = store.localizer
        let sortedItems = sorted(items)
        let groups = Dictionary(grouping: sortedItems, by: \.category)
        let categories = FileCategory.allCases.filter { groups[$0] != nil }

        LazyVStack(alignment: .leading, spacing: 10) {
            if items.isEmpty {
                EmptyStateView(text: l("no.files"), systemImage: "folder.badge.questionmark")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 70)
            } else {
                FileTableHeader(language: store.language)
                ForEach(categories) { category in
                    VStack(spacing: 0) {
                        Button {
                            if collapsedCategories.contains(category) {
                                collapsedCategories.remove(category)
                            } else {
                                collapsedCategories.insert(category)
                            }
                        } label: {
                            HStack {
                                Image(systemName: collapsedCategories.contains(category) ? "chevron.right" : "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 12)
                                Image(systemName: category.iconName)
                                    .foregroundStyle(AppTheme.primary)
                                    .frame(width: 20)
                                Text(category.title(store.language))
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text("\((groups[category] ?? []).count) · \((groups[category] ?? []).reduce(0) { $0 + $1.size }.cleanerFileSize)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(AppTheme.primary.opacity(0.09))

                        if !collapsedCategories.contains(category) {
                            ForEach(groups[category] ?? []) { item in
                                FileRow(item: item, store: store)
                                if item.id != groups[category]?.last?.id {
                                    Divider().padding(.leading, 48)
                                }
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.inset))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line.opacity(0.55), lineWidth: 1))
                }
            }
        }
        .padding(14)
    }

    private func sorted(_ items: [FileItem]) -> [FileItem] {
        switch sort {
        case .category:
            return items.sorted {
                if $0.category == $1.category { return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                return categoryIndex($0.category) < categoryIndex($1.category)
            }
        case .name:
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .size:
            return items.sorted { $0.size > $1.size }
        case .date:
            return items.sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
        }
    }

    private func categoryIndex(_ category: FileCategory) -> Int {
        FileCategory.allCases.firstIndex(of: category) ?? Int.max
    }
}

private struct FileTableHeader: View {
    let language: AppLanguage

    var body: some View {
        let l = Localizer(language: language)
        HStack {
            Text(l("sort.name"))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(l("modified"))
                .frame(width: 96, alignment: .trailing)
            Text(l("size"))
                .frame(width: 78, alignment: .trailing)
            Spacer().frame(width: 28)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AppTheme.controlFill.opacity(0.38)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.line.opacity(0.35), lineWidth: 1))
    }
}

private struct FileRow: View {
    let item: FileItem
    @ObservedObject var store: CleanerStore

    var body: some View {
        let isSelected = store.selectedFileIDs.contains(item.id)

        HStack(spacing: 10) {
            Button {
                store.toggleSelection(for: item)
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(item.isRemovable ? AppTheme.primary : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!item.isRemovable)

            FileIconView(item: item, size: 22)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    if item.isRecommended {
                        Chip(label: store.localizer("recommended"), systemImage: "checkmark", color: AppTheme.accent)
                    }
                    if item.scope == .system {
                        Chip(label: item.scope.title(store.language), systemImage: "desktopcomputer", color: AppTheme.amber)
                    }
                    if !item.isRemovable {
                        ForEach(item.protectionReasons, id: \.rawValue) { reason in
                            Chip(label: reason.title(store.language), systemImage: "lock", color: .secondary)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Text(item.url.abbreviatedPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let detail = item.detail {
                        Text("· \(detail)")
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            if let modifiedAt = item.modifiedAt {
                Text(DateFormatter.cleanerShort.string(from: modifiedAt))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 96, alignment: .trailing)
            }

            Text(item.size.cleanerFileSize)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .trailing)

            Button {
                store.reveal(item.url)
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help(store.localizer("open.finder"))
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 50)
        .background(rowBackground(isSelected: isSelected))
        .opacity(item.isRemovable ? 1 : 0.72)
    }

    private func rowBackground(isSelected: Bool) -> Color {
        if isSelected {
            return AppTheme.primary.opacity(0.08)
        }
        if item.scope == .system {
            return AppTheme.amber.opacity(0.055)
        }
        return Color.clear
    }
}

private struct AppIconView: View {
    let url: URL
    let size: CGFloat

    var body: some View {
        IconImageView(url: url, size: size, cornerRadius: min(10, size * 0.22))
            .shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 1)
    }
}

private struct FileIconView: View {
    let item: FileItem
    let size: CGFloat

    var body: some View {
        IconImageView(
            url: item.iconURL ?? item.url,
            size: size,
            cornerRadius: item.category == .appBundle || item.iconURL?.pathExtension.lowercased() == "app" ? min(6, size * 0.22) : 4
        )
    }
}

private struct IconImageView: View {
    let url: URL
    let size: CGFloat
    let cornerRadius: CGFloat
    @State private var image: NSImage?

    var body: some View {
        Image(nsImage: image ?? NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear(perform: loadIcon)
            .onChange(of: url) { _ in loadIcon() }
    }

    private func loadIcon() {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: size, height: size)
        image = icon
    }
}

private struct MetadataLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 76, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

private struct SectionCaption: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.primary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
        }
    }
}

private struct InfoBanner: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.20), lineWidth: 1))
    }
}

private struct Chip: View {
    let label: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.12)))
        .overlay(Capsule().stroke(color.opacity(0.20), lineWidth: 1))
    }
}

private struct MetricPill: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.primary)
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.elevatedPanel))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line.opacity(0.55), lineWidth: 1))
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(AppTheme.primary)
                Spacer()
            }
            Text(value)
                .font(.system(size: 22, weight: .semibold))
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .panelStyle()
    }
}

private struct EmptyStateView: View {
    let text: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangeSubviews(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrangeSubviews(proposal: ProposedViewSize(width: bounds.width, height: proposal.height), subviews: subviews)
        for item in arrangement.items {
            subviews[item.index].place(
                at: CGPoint(x: bounds.minX + item.origin.x, y: bounds.minY + item.origin.y),
                proposal: ProposedViewSize(item.size)
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (items: [(index: Int, origin: CGPoint, size: CGSize)], size: CGSize) {
        let maxWidth = proposal.width ?? 360
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var items: [(index: Int, origin: CGPoint, size: CGSize)] = []

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            items.append((index, CGPoint(x: x, y: y), size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return (items, CGSize(width: maxWidth, height: y + rowHeight))
    }
}

private extension View {
    func panelStyle() -> some View {
        padding(14)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AppTheme.elevatedPanel))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.line.opacity(0.50), lineWidth: 1))
    }

    func scrollSurfaceStyle() -> some View {
        background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AppTheme.elevatedPanel.opacity(0.78)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.line.opacity(0.42), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
