import AppKit
import SwiftUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var sharedDelegate: AppDelegate?

    private var mainWindow: NSWindow?
    private let captureURL: URL? = {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--capture-ui") else { return nil }
        let pathIndex = arguments.index(after: index)
        guard arguments.indices.contains(pathIndex) else { return nil }
        return URL(fileURLWithPath: arguments[pathIndex])
    }()

    static func main() {
        if CommandLine.arguments.contains("--self-test") {
            exit(SelfTestRunner.run())
        }

        let application = NSApplication.shared
        let delegate = AppDelegate()
        sharedDelegate = delegate
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        showMainWindow()
        NSApp.activate(ignoringOtherApps: true)

        Task { @MainActor in
            SparkleUpdateController.shared.startIfConfigured()
        }

        if let captureURL {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                captureMainWindow(to: captureURL)
                exit(0)
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        showMainWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc private func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel(
            options: [
                .applicationName: "MacCleanKit",
                .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "debug",
                .credits: NSAttributedString(string: "Native macOS cleanup and app management prototype.")
            ]
        )
    }

    @objc private func checkForUpdates() {
        SparkleUpdateController.shared.checkForUpdates()
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "MacCleanKit")
        appMenuItem.submenu = appMenu

        let aboutItem = NSMenuItem(title: "About MacCleanKit", action: #selector(showAboutPanel), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)

        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        updateItem.isEnabled = SparkleUpdateController.shared.isConfigured
        appMenu.addItem(updateItem)

        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit MacCleanKit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)

        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    private func showMainWindow() {
        let frame = defaultMainWindowFrame()

        if let mainWindow {
            if mainWindow.frame.width < 200 || mainWindow.frame.height < 200 {
                mainWindow.setFrame(frame, display: true)
                mainWindow.center()
            }
            mainWindow.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MacCleanKit"
        window.identifier = NSUserInterfaceItemIdentifier("MacCleanKitMainWindow")
        window.isRestorable = false
        window.minSize = NSSize(width: 980, height: 680)
        window.contentView = NSHostingView(rootView: ContentView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        mainWindow = window
    }

    private func defaultMainWindowFrame() -> NSRect {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 80, y: 80, width: 1280, height: 820)
        let width: CGFloat = min(1180, max(980, visibleFrame.width * 0.78))
        let height: CGFloat = min(760, max(680, visibleFrame.height * 0.78))
        return NSRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func captureMainWindow(to url: URL) {
        guard let window = mainWindow, let contentView = window.contentView else { return }
        contentView.layoutSubtreeIfNeeded()
        contentView.displayIfNeeded()

        let bounds = contentView.bounds
        guard bounds.width > 0, bounds.height > 0,
              let bitmap = contentView.bitmapImageRepForCachingDisplay(in: bounds) else { return }

        bitmap.size = bounds.size
        contentView.cacheDisplay(in: bounds, to: bitmap)

        guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
