import AppKit
import ServiceManagement
import SwiftUI

@main
enum Main {
    static func main() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--selftest") {
            _ = NSApplication.shared
            Prefs.registerDefaults()
            let outDir = args.count > i + 1 ? args[i + 1] : nil
            exit(MainActor.assumeIsolated { SelfTest.run(outDir: outDir) })
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

/// Accessibility permission state, polled until granted.
final class Permission: ObservableObject {
    static let shared = Permission()
    @Published private(set) var trusted = AX.isTrusted
    private var timer: Timer?

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = AX.isTrusted
            if now != trusted { trusted = now }
            if now {
                timer?.invalidate()
                timer = nil
                Coach.shared.startMonitoring()
            }
        }
    }

    func openSettings() {
        AX.requestTrust()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            Log.info("Launch at login change failed: \(error.localizedDescription)")
        }
    }
}

/// Which page of the main window to show.
final class Navigation: ObservableObject {
    static let shared = Navigation()
    @Published var section: MainSection = .overview
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate, NSMenuItemValidation {
    private var statusItem: NSStatusItem!
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.registerDefaults()
        Log.info("Launched (trusted=\(AX.isTrusted))")
        buildMainMenu()
        setupStatusItem()
        FrontmostTracker.shared.start()
        TipScheduler.shared.start()

        if AX.isTrusted {
            Coach.shared.startMonitoring()
        } else {
            // The welcome tour explains the permission first; otherwise ask straight away.
            if Prefs.d.bool(forKey: Prefs.Key.hasOnboarded) { AX.requestTrust() }
            Permission.shared.startPolling()
        }

        Prefs.d.set(true, forKey: Prefs.Key.hasLaunched)
        let relaunchedForUpdate = Prefs.d.bool(forKey: Prefs.Key.relaunchedForUpdate)
        Prefs.d.removeObject(forKey: Prefs.Key.relaunchedForUpdate)
        if !Prefs.d.bool(forKey: Prefs.Key.hasOnboarded) {
            Onboarding.shared.show()
        } else if !(launchedAsLoginItem || relaunchedForUpdate) || !AX.isTrusted {
            // Opening the app by hand shows its window; starting at login or after an update stays in the menu bar.
            showWindow(nil)
        }
        Updates.shared.start()
    }

    /// True when macOS started the app as a login item rather than the user opening it.
    private var launchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == kAEOpenApplication else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow(nil)
        return true
    }

    // MARK: Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "command.square", accessibilityDescription: "Shortcut Coach")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu == statusItem.menu else { return }
        menu.removeAllItems()

        let status: String
        if !AX.isTrusted { status = "Needs Accessibility access" }
        else if !Prefs.enabled { status = "Paused" }
        else if Coach.shared.isMonitoring { status = "Coaching is on" }
        else { status = "Starting…" }
        let header = NSMenuItem(title: "Shortcut Coach \(Updates.version) — \(status)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        if let version = Updates.shared.readyVersion {
            menu.addItem(item("Install Update \(version) and Relaunch", #selector(installUpdate)))
        }
        menu.addItem(.separator())

        menu.addItem(item("Open Shortcut Coach…", #selector(showWindow(_:)), key: "o"))
        if let app = FrontmostTracker.shared.lastExternalApp, let name = app.localizedName {
            menu.addItem(item("Show Shortcuts for \(name)", #selector(showOverlay)))
        }
        menu.addItem(item("Show a Tip", #selector(showTip)))
        let pause = item(Prefs.enabled ? "Pause Coaching" : "Resume Coaching", #selector(togglePause), key: "P")
        menu.addItem(pause)
        menu.addItem(.separator())
        if !AX.isTrusted {
            menu.addItem(item("Grant Accessibility Access…", #selector(grantAccess)))
        }
        menu.addItem(item("Settings…", #selector(showSettings), key: ","))
        if Updates.shared.isAvailable {
            menu.addItem(item("Check for Updates…", #selector(checkForUpdates)))
        }
        menu.addItem(item("Quit Shortcut Coach", #selector(NSApplication.terminate(_:)), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = action == #selector(NSApplication.terminate(_:)) ? NSApp : self
        return i
    }

    @objc func showOverlay() {
        // The status menu doesn't activate us, so the user's app is still frontmost.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { Coach.shared.showOverlayForFrontApp() }
    }

    @objc func showTip() { TipScheduler.shared.showNext() }

    @objc func togglePause() {
        Prefs.d.set(!Prefs.enabled, forKey: Prefs.Key.enabled)
        if !Prefs.enabled { Toast.shared.dismiss() }
    }

    /// Keeps the ⇧⌘P item's title in step with the current state, in both the main menu and the status menu.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(togglePause) {
            menuItem.title = Prefs.enabled ? "Pause Coaching" : "Resume Coaching"
        }
        if menuItem.action == #selector(checkForUpdates) { return Updates.shared.isAvailable }
        return true
    }

    @objc func grantAccess() { Permission.shared.openSettings() }

    @objc func checkForUpdates() { Updates.shared.checkForUpdates(nil) }

    @objc func installUpdate() { Updates.shared.installNow() }

    @objc func showSettings() {
        Navigation.shared.section = .settings
        showWindow(nil)
    }

    // MARK: Main window

    @objc func showWindow(_ sender: Any?) {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 680),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = "Shortcut Coach"
            // Transparent, so there's no toolbar band (macOS draws an opaque one in inactive windows otherwise).
            // Scrolling sections fade their content out before it reaches the toolbar instead: see sectionGround().
            w.titlebarAppearsTransparent = true
            w.toolbarStyle = .unified
            w.minSize = NSSize(width: 820, height: 520)
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.contentViewController = NSHostingController(rootView: MainView())
            w.setContentSize(NSSize(width: 980, height: 680))
            w.center()
            w.setFrameAutosaveName("ShortcutCoachMain")
            window = w
        }
        // Become a regular app while the window is open so it shows in ⌘⇥ and the Dock.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func buildMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Shortcut Coach", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        let update = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        update.target = self
        appMenu.addItem(update)
        appMenu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        // "P" (uppercase) is ⇧⌘P. The Overview toolbar pill shows these keys.
        let pause = NSMenuItem(title: "Pause Coaching", action: #selector(togglePause), keyEquivalent: "P")
        pause.target = self
        appMenu.addItem(pause)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Shortcut Coach", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Shortcut Coach", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Find", action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: "f")
        editItem.submenu = edit
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = main
    }
}
