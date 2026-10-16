import AppKit
import Sparkle

/// Sparkle updates from the feed on the latest GitHub release (SUFeedURL in Info.plist).
/// Updates download in the background, then wait for the user: a toast, the menu-bar menu and Settings
/// offer Install and Relaunch, and otherwise Sparkle installs it when the app next quits.
final class Updates: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = Updates()
    private var controller: SPUStandardUpdaterController?
    private var pendingInstall: (() -> Void)?
    /// The downloaded version waiting to be installed.
    @Published private(set) var readyVersion: String?

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    /// Only inside an app bundle; the bare binary (swift run, --selftest) has no feed.
    var isAvailable: Bool { controller != nil }

    func start() {
        guard controller == nil, Bundle.main.bundleURL.pathExtension == "app" else { return }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
        announceIfUpdated()
    }

    /// However the update was installed (now, or on quit), say so on the first launch of the new build.
    private func announceIfUpdated() {
        let build = Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "") ?? 0
        let last = Prefs.d.integer(forKey: Prefs.Key.lastRunBuild)
        if last > 0, build > last { Toast.shared.show(.updated(Self.version)) }
        Prefs.d.set(build, forKey: Prefs.Key.lastRunBuild)
    }

    @objc func checkForUpdates(_ sender: Any?) { controller?.checkForUpdates(sender) }

    /// Off still checks, but asks before downloading.
    var downloadsAutomatically: Bool {
        get { controller?.updater.automaticallyDownloadsUpdates ?? false }
        set {
            controller?.updater.automaticallyChecksForUpdates = true
            controller?.updater.automaticallyDownloadsUpdates = newValue
        }
    }

    @objc func installNow() {
        guard let install = pendingInstall else { return }
        Log.info("Installing update \(readyVersion ?? "")")
        install()
    }

    // MARK: SPUUpdaterDelegate

    /// Returning true holds the install until installNow(); Sparkle still installs on quit.
    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
                 immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        Log.info("Update \(item.displayVersionString) downloaded")
        pendingInstall = immediateInstallHandler
        readyVersion = item.displayVersionString
        Toast.shared.show(.updateReady(item.displayVersionString))
        return true
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        // Installed from the menu bar or the toast: come back the same way, in the menu bar.
        if NSApp.activationPolicy() == .accessory {
            Prefs.d.set(true, forKey: Prefs.Key.relaunchedForUpdate)
        }
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        guard (error as NSError).code != Int(SUError.noUpdateError.rawValue) else { return }
        Log.info("Update failed: \(error.localizedDescription)")
    }
}

extension ToastModel {
    static func updateReady(_ version: String) -> ToastModel {
        ToastModel(style: .suggestion, bundleID: nil, symbol: "arrow.down.circle", eyebrow: "Update ready",
                   title: "Shortcut Coach \(version)",
                   message: "Install it now and the app relaunches, or it installs the next time you quit.",
                   actions: [ToastAction(title: "Install and Relaunch") { Updates.shared.installNow() }])
    }

    static func updated(_ version: String) -> ToastModel {
        ToastModel(style: .suggestion, bundleID: nil, symbol: "checkmark.circle", eyebrow: "Updated",
                   title: "Shortcut Coach \(version)")
    }
}
