import AppKit

extension Notification.Name {
    static let hintShown = Notification.Name("ShortcutCoach.hintShown")
    static let shortcutUsed = Notification.Name("ShortcutCoach.shortcutUsed")
    static let overlayShown = Notification.Name("ShortcutCoach.overlayShown")
}

/// Main-thread coordinator: owns the event tap, applies cooldowns/mutes, records stats and shows toasts.
final class Coach: ObservableObject {
    static let shared = Coach()

    @Published private(set) var isMonitoring = false

    private let detector = Detector()
    private var monitor: EventMonitor?
    private var lastShown: [String: Date] = [:]
    private var holdTimer: Timer?

    // MARK: Lifecycle

    func startMonitoring() {
        guard monitor == nil else { return }
        let detector = self.detector
        let m = EventMonitor { type, event in detector.handle(type, event) }
        if m.start() {
            monitor = m
            isMonitoring = true
        }
    }

    // MARK: Hints

    func show(_ hint: Hint) {
        guard Prefs.enabled, !Prefs.isIgnored(hint.bundleID) else { return }
        let record = StatsStore.shared.recordShown(hint)
        Log.info("hint \(hint.id) [\(hint.keycapGroups.map { $0.joined() }.joined(separator: " / "))] shown=\(record.shown) used=\(record.used)\(record.muted ? " (muted)" : "")")
        guard !record.muted else { return }

        // Shortcuts you already know stay quiet until you've used the mouse N times in a row.
        var reminder = false
        if record.isKnown, Prefs.on(Prefs.Key.quietKnown) {
            let n = Prefs.d.integer(forKey: Prefs.Key.remindAfter)
            guard n > 0, record.mouseStreak >= n else { return }
            reminder = true
            StatsStore.shared.resetStreak(hint.id)
        }

        let now = Date()
        if !reminder, let last = lastShown[hint.id], now.timeIntervalSince(last) < Prefs.cooldown { return }
        lastShown[hint.id] = now
        Toast.shared.show(.hint(hint, record: record, reminder: reminder))
        NotificationCenter.default.post(name: .hintShown, object: hint.id)
    }

    /// A modified keystroke happened: credit matching hints and celebrate milestones.
    func comboTyped(_ combo: KeyCombo, bundleID: String?) {
        let updated = StatsStore.shared.recordUsed(combo, bundleID: bundleID)
        guard Prefs.enabled, Prefs.on(Prefs.Key.celebrate) else { return }
        if !updated.isEmpty { NotificationCenter.default.post(name: .shortcutUsed, object: nil) }
        // No applause for shortcuts you already knew before the first hint.
        if let r = updated.first(where: { !$0.alreadyKnown && [1, HintRecord.learnedThreshold, 25].contains($0.used) }) {
            Log.info("used \(r.id) (\(r.used)×)")
            Toast.shared.show(.celebration(r))
        }
    }

    func menuItemWithoutShortcut(app: AppInfo, path: [String]) {
        guard Prefs.enabled, let title = path.last else { return }
        let id = "\(app.bundleID ?? app.name)|noshortcut|\(path.joined(separator: "->"))"
        let n = StatsStore.shared.bumpNoShortcut(id)
        let threshold = Prefs.noShortcutThreshold
        guard n >= threshold, (n - threshold) % 5 == 0 else { return }
        Log.info("suggest custom shortcut for \(id) (\(n)×)")
        Toast.shared.show(.noShortcut(appName: app.name, bundleID: app.bundleID, title: title, path: path, count: n))
    }

    // MARK: Hold-⌘ overlay (called from the tap thread)

    static func userActivity() {
        DispatchQueue.main.async {
            shared.holdTimer?.invalidate()
            shared.holdTimer = nil
            Overlay.shared.dismiss()
        }
    }

    static func flagsChanged(_ mods: Mods) {
        DispatchQueue.main.async { shared.flagsChanged(mods) }
    }

    private func flagsChanged(_ mods: Mods) {
        holdTimer?.invalidate()
        holdTimer = nil
        guard mods == [.command], Prefs.enabled, Prefs.on(Prefs.Key.holdOverlay),
              NSEvent.pressedMouseButtons == 0, !Overlay.shared.isVisible else { return }
        holdTimer = Timer.scheduledTimer(withTimeInterval: Prefs.holdDelay, repeats: false) { _ in
            // Make sure ⌘ is still the only modifier held.
            guard Mods(CGEventSource.flagsState(.combinedSessionState)) == [.command] else { return }
            Coach.shared.showOverlayForFrontApp()
        }
    }

    func showOverlayForFrontApp() {
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != Apps.ownPID else { return }
        Overlay.shared.show(for: app)
    }
}
