import AppKit
import Sparkle

/// Sparkle updates from the feed on the latest GitHub release (SUFeedURL in Info.plist).
/// Updates download in the background and install with a relaunch as soon as no window is open,
/// so a menu-bar app that never quits still picks them up.
final class Updates: NSObject, SPUUpdaterDelegate {
    static let shared = Updates()
    private var controller: SPUStandardUpdaterController?
    private var pendingInstall: (() -> Void)?

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    /// Only inside an app bundle; the bare binary (swift run, --selftest) has no feed.
    var isAvailable: Bool { controller != nil }

    func start() {
        guard controller == nil, Bundle.main.bundleURL.pathExtension == "app" else { return }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
    }

    @objc func checkForUpdates(_ sender: Any?) { controller?.checkForUpdates(sender) }

    /// Off still checks, but asks before downloading.
    var installsAutomatically: Bool {
        get { controller?.updater.automaticallyDownloadsUpdates ?? false }
        set {
            controller?.updater.automaticallyChecksForUpdates = true
            controller?.updater.automaticallyDownloadsUpdates = newValue
        }
    }

    /// Install now and relaunch, unless a window is open (the app is .regular then); see AppDelegate.windowWillClose.
    func installIfIdle() {
        guard let install = pendingInstall, NSApp.activationPolicy() == .accessory else { return }
        pendingInstall = nil
        Log.info("Installing update")
        install()
    }

    // MARK: SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
                 immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        Log.info("Update \(item.displayVersionString) downloaded")
        pendingInstall = immediateInstallHandler
        installIfIdle()
        return true
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        // The relaunch should stay in the menu bar like a login launch, not open the window.
        Prefs.d.set(true, forKey: Prefs.Key.relaunchedForUpdate)
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        guard (error as NSError).code != Int(SUError.noUpdateError.rawValue) else { return }
        Log.info("Update failed: \(error.localizedDescription)")
    }
}
