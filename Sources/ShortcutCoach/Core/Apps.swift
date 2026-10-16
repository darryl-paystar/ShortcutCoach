import AppKit

/// Thread-safe facts about running apps, readable from the event-tap thread.
struct AppInfo {
    enum Engine { case native, chromium, webShell }

    let pid: pid_t
    let bundleID: String?
    let name: String
    let engine: Engine

    var isBrowser: Bool { bundleID.map(Apps.browsers.contains) ?? false }
    var isFinder: Bool { bundleID == "com.apple.finder" }
    /// Apple's own apps and system UI (Finder, Safari, Mail, Dock, System Settings…).
    var isApple: Bool { bundleID?.hasPrefix("com.apple.") ?? false }
}

enum Apps {
    static let ownPID = ProcessInfo.processInfo.processIdentifier

    static let chromiumBrowsers: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary", "com.brave.Browser",
        "com.microsoft.edgemac", "company.thebrowser.Browser", "company.thebrowser.dia",
        "com.vivaldi.Vivaldi", "com.operasoftware.Opera", "org.chromium.Chromium",
    ]
    static let firefoxes: Set<String> = [
        "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition", "org.mozilla.nightly", "app.zen-browser.zen",
    ]
    static let browsers: Set<String> = chromiumBrowsers
        .union(firefoxes)
        .union(["com.apple.Safari", "com.apple.SafariTechnologyPreview"])

    private static let lock = NSLock()
    private static var cache: [pid_t: AppInfo] = [:]
    private static var frontPID: pid_t = 0

    static func info(pid: pid_t) -> AppInfo {
        lock.lock()
        if let hit = cache[pid] { lock.unlock(); return hit }
        lock.unlock()

        let app = NSRunningApplication(processIdentifier: pid)
        let bid = app?.bundleIdentifier
        var engine = AppInfo.Engine.native
        if let bid, chromiumBrowsers.contains(bid) {
            engine = .chromium
        } else if let bid, firefoxes.contains(bid) {
            engine = .webShell
        } else if let url = app?.bundleURL,
                  FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/Frameworks/Electron Framework.framework").path) {
            engine = .webShell
        }
        let info = AppInfo(pid: pid, bundleID: bid, name: app?.localizedName ?? bid ?? "App", engine: engine)
        lock.lock()
        cache[pid] = info
        lock.unlock()
        return info
    }

    static var front: AppInfo? {
        lock.lock()
        let pid = frontPID
        lock.unlock()
        return pid == 0 ? nil : info(pid: pid)
    }

    static func setFront(_ pid: pid_t) {
        lock.lock()
        frontPID = pid
        lock.unlock()
    }

    static func forget(_ pid: pid_t) {
        lock.lock()
        cache[pid] = nil
        lock.unlock()
    }

    static func isRunning(_ bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    static func icon(for bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
           let icon = running.icon { return icon }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    static func name(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }
}

/// Tracks the frontmost app (and the last one that wasn't us) on the main thread.
final class FrontmostTracker: ObservableObject {
    static let shared = FrontmostTracker()

    @Published private(set) var lastExternalApp: NSRunningApplication?
    private var observers: [NSObjectProtocol] = []

    func start() {
        if let app = NSWorkspace.shared.frontmostApplication { activated(app) }
        let nc = NSWorkspace.shared.notificationCenter
        observers.append(nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication { self?.activated(app) }
        })
        observers.append(nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                Apps.forget(app.processIdentifier)
                MenuIndex.shared.forget(app.processIdentifier)
            }
        })
    }

    private func activated(_ app: NSRunningApplication) {
        Apps.setFront(app.processIdentifier)
        guard app.processIdentifier != Apps.ownPID else { return }
        lastExternalApp = app
        Overlay.shared.dismiss()
        // Warm the menu cache so toolbar/sidebar lookups are instant later.
        MenuIndex.shared.refresh(pid: app.processIdentifier)
    }
}
