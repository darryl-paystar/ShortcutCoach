import Foundation

/// UserDefaults-backed settings. Views bind to the same keys with @AppStorage.
enum Prefs {
    enum Key {
        static let enabled = "enabled"
        static let appleAppsOnly = "appleAppsOnly"
        static let hintMenus = "hintMenus"
        static let hintButtons = "hintButtons"
        static let hintWindowControls = "hintWindowControls"
        static let hintDialogs = "hintDialogs"
        static let hintDock = "hintDock"
        static let hintBrowser = "hintBrowser"
        static let hintFinder = "hintFinder"
        static let hintWindowsHabits = "hintWindowsHabits"
        static let hintTextEditing = "hintTextEditing"
        static let suggestCustomShortcuts = "suggestCustomShortcuts"
        static let noShortcutThreshold = "noShortcutThreshold"
        static let celebrate = "celebrate"
        static let quietKnown = "quietKnown"
        static let remindAfter = "remindAfterMouseUses"
        static let hasOnboarded = "hasOnboarded"
        static let cooldown = "cooldownSeconds"
        static let holdOverlay = "holdOverlay"
        static let holdDelay = "holdDelay"
        static let periodicTips = "periodicTips"
        static let tipInterval = "tipIntervalMinutes"
        static let toastPosition = "toastPosition"
        static let toastDuration = "toastDuration"
        static let habitExclusions = "habitExclusions"
        static let ignoredApps = "ignoredApps"
        static let debugLogging = "debugLogging"
        static let hasLaunched = "hasLaunchedBefore"
        static let tipIndex = "tipIndex"
        static let lastTipAt = "lastTipAt"
        static let relaunchedForUpdate = "relaunchedForUpdate"
    }

    static let d = UserDefaults.standard

    /// Terminals and IDEs where ⌃-keys, arrows and Home/End legitimately mean something else.
    static let defaultHabitExclusions = [
        "com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "com.mitchellh.ghostty",
        "io.alacritty", "net.kovidgoyal.kitty", "com.github.wez.wezterm",
        "com.microsoft.VSCode", "dev.zed.Zed", "com.todesktop.230313mzl4w4u92",
        "com.jetbrains.*", "com.sublimetext.4", "com.apple.dt.Xcode",
    ]

    static func registerDefaults() {
        d.register(defaults: [
            Key.enabled: true,
            Key.appleAppsOnly: true,
            Key.hintMenus: true,
            Key.hintButtons: true,
            Key.hintWindowControls: true,
            Key.hintDialogs: true,
            Key.hintDock: true,
            Key.hintBrowser: true,
            Key.hintFinder: true,
            Key.hintWindowsHabits: true,
            Key.hintTextEditing: true,
            Key.suggestCustomShortcuts: true,
            Key.noShortcutThreshold: 3,
            Key.celebrate: true,
            Key.quietKnown: true,
            Key.remindAfter: 5,
            Key.cooldown: 20.0,
            Key.holdOverlay: true,
            Key.holdDelay: 1.2,
            Key.periodicTips: true,
            Key.tipInterval: 45,
            Key.toastPosition: ToastPosition.bottomRight.rawValue,
            Key.toastDuration: 5.0,
            Key.habitExclusions: defaultHabitExclusions,
            Key.ignoredApps: [String](),
            Key.debugLogging: false,
        ])
    }

    static var enabled: Bool { d.bool(forKey: Key.enabled) }
    static func on(_ key: String) -> Bool { d.bool(forKey: key) }
    static var cooldown: TimeInterval { d.double(forKey: Key.cooldown) }
    static var holdDelay: TimeInterval { max(0.4, d.double(forKey: Key.holdDelay)) }
    static var toastDuration: TimeInterval { max(2, d.double(forKey: Key.toastDuration)) }
    static var tipInterval: TimeInterval { TimeInterval(max(5, d.integer(forKey: Key.tipInterval)) * 60) }
    static var noShortcutThreshold: Int { max(1, d.integer(forKey: Key.noShortcutThreshold)) }
    static var toastPosition: ToastPosition { ToastPosition(rawValue: d.string(forKey: Key.toastPosition) ?? "") ?? .bottomRight }
    static var debugLogging: Bool { d.bool(forKey: Key.debugLogging) }

    static var habitExclusions: [String] { d.stringArray(forKey: Key.habitExclusions) ?? [] }
    static var ignoredApps: [String] { d.stringArray(forKey: Key.ignoredApps) ?? [] }

    static func isIgnored(_ bundleID: String?) -> Bool { matches(bundleID, ignoredApps) }
    static func isHabitExcluded(_ bundleID: String?) -> Bool { matches(bundleID, habitExclusions) || isIgnored(bundleID) }

    /// Supports a trailing "*" wildcard, e.g. "com.jetbrains.*".
    private static func matches(_ bundleID: String?, _ list: [String]) -> Bool {
        guard let id = bundleID else { return false }
        return list.contains { pattern in
            pattern.hasSuffix("*") ? id.hasPrefix(String(pattern.dropLast())) : id == pattern
        }
    }
}

enum ToastPosition: String, CaseIterable, Identifiable {
    case bottomRight, bottomCenter, topRight, topCenter
    var id: String { rawValue }
    var label: String {
        switch self {
        case .bottomRight: "Bottom right"
        case .bottomCenter: "Bottom center"
        case .topRight: "Top right"
        case .topCenter: "Top center"
        }
    }
}
