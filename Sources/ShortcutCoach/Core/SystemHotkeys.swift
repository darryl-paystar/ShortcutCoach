import Foundation

/// The user's real system-wide shortcut bindings (System Settings → Keyboard → Keyboard Shortcuts),
/// read from com.apple.symbolichotkeys, plus Raycast's launcher hotkey. Built-in hints and cheat sheets
/// use this instead of assuming macOS defaults.
enum SystemHotkeys {
    /// Symbolic hotkey IDs used by macOS.
    enum ID: Int, CaseIterable {
        case missionControl = 32
        case appWindows = 33
        case showDesktop = 36
        case spotlight = 64
        case finderSearch = 65

        var defaultCombo: KeyCombo {
            switch self {
            case .missionControl: KeyCombo([.control], "↑")
            case .appWindows: KeyCombo([.control], "↓")
            case .showDesktop: KeyCombo([], "F11")
            case .spotlight: KeyCombo([.command], "Space")
            case .finderSearch: KeyCombo([.option, .command], "Space")
            }
        }
    }

    enum State: Equatable {
        case enabled(KeyCombo)
        case disabled
    }

    static func state(_ id: ID) -> State {
        guard let all = UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys"),
              let entry = all[String(id.rawValue)] as? [String: Any] else { return .enabled(id.defaultCombo) }
        if let enabled = entry["enabled"] as? Bool, !enabled { return .disabled }
        guard let value = entry["value"] as? [String: Any],
              let params = value["parameters"] as? [Int], params.count == 3 else { return .enabled(id.defaultCombo) }
        return .enabled(combo(char: params[0], keyCode: params[1], flags: params[2]))
    }

    /// The combo if the system shortcut is on, nil if it's turned off.
    static func combo(_ id: ID) -> KeyCombo? {
        if case .enabled(let c) = state(id) { return c }
        return nil
    }

    /// What launches apps on this Mac: Spotlight if its shortcut is on, otherwise Raycast's hotkey.
    static var launcher: (name: String, combo: KeyCombo)? {
        if let c = combo(.spotlight) { return ("Spotlight", c) }
        if let c = raycastHotkey { return ("Raycast", c) }
        return nil
    }

    /// Raycast stores its hotkey as e.g. "Command-49" (modifier names + virtual key code).
    static var raycastHotkey: KeyCombo? {
        guard let raw = UserDefaults(suiteName: "com.raycast.macos")?.string(forKey: "raycastGlobalHotkey") else { return nil }
        let parts = raw.split(separator: "-").map(String.init)
        guard let last = parts.last, let code = Int(last) else { return nil }
        var mods: Mods = []
        for p in parts.dropLast() {
            switch p.lowercased() {
            case "command": mods.insert(.command)
            case "option", "alt": mods.insert(.option)
            case "control": mods.insert(.control)
            case "shift": mods.insert(.shift)
            default: break
            }
        }
        return KeyCombo(mods, KeyNames.byKeyCode[code] ?? KeyNames.ansiLetters[code] ?? "key \(code)")
    }

    private static func combo(char: Int, keyCode: Int, flags: Int) -> KeyCombo {
        var mods: Mods = []
        if flags & (1 << 17) != 0 { mods.insert(.shift) }
        if flags & (1 << 18) != 0 { mods.insert(.control) }
        if flags & (1 << 19) != 0 { mods.insert(.option) }
        if flags & (1 << 20) != 0 { mods.insert(.command) }
        // macOS sets the fn flag on arrow / F-keys automatically; it only means "hold fn" for other keys.
        if flags & (1 << 23) != 0, KeyNames.byKeyCode[keyCode] == nil { mods.insert(.fn) }
        if let name = KeyNames.byKeyCode[keyCode] { return KeyCombo(mods, name) }
        if char > 0, char < 65535, let scalar = Unicode.Scalar(char) { return KeyCombo(mods, String(Character(scalar)).uppercased()) }
        return KeyCombo(mods, KeyNames.ansiLetters[keyCode] ?? "key \(keyCode)")
    }

    /// Adjusts a cheat-sheet row that refers to a system shortcut: real binding, or a note that it's off.
    static func resolve(_ id: ID) -> (keys: [String], note: String?) {
        switch state(id) {
        case .enabled(let c):
            return ([c.display], c == id.defaultCombo ? nil : "Customized on this Mac (default \(id.defaultCombo.display))")
        case .disabled:
            if id == .spotlight, let r = raycastHotkey {
                return ([r.display], "Spotlight's shortcut is off on this Mac — Raycast uses \(r.display)")
            }
            return ([id.defaultCombo.display], "Turned off on this Mac — enable it in System Settings → Keyboard → Keyboard Shortcuts")
        }
    }
}
