import AppKit
import CoreGraphics

/// Modifier set, ordered the way macOS displays them: fn ⌃ ⌥ ⇧ ⌘.
struct Mods: OptionSet, Codable, Hashable {
    let rawValue: Int
    init(rawValue: Int) { self.rawValue = rawValue }

    static let control = Mods(rawValue: 1 << 0)
    static let option  = Mods(rawValue: 1 << 1)
    static let shift   = Mods(rawValue: 1 << 2)
    static let command = Mods(rawValue: 1 << 3)
    static let fn      = Mods(rawValue: 1 << 4)

    /// fn is deliberately ignored: macOS sets it on every arrow / F-key press.
    init(_ flags: CGEventFlags) {
        var m: Mods = []
        if flags.contains(.maskControl) { m.insert(.control) }
        if flags.contains(.maskAlternate) { m.insert(.option) }
        if flags.contains(.maskShift) { m.insert(.shift) }
        if flags.contains(.maskCommand) { m.insert(.command) }
        self = m
    }

    /// AX menu modifier bitmask: 0 = ⌘ only; 1 shift, 2 option, 4 control, 8 = no ⌘.
    init(axMenuModifiers v: Int) {
        var m: Mods = []
        if v & 1 != 0 { m.insert(.shift) }
        if v & 2 != 0 { m.insert(.option) }
        if v & 4 != 0 { m.insert(.control) }
        if v & 8 == 0 { m.insert(.command) }
        self = m
    }

    var symbols: [String] {
        var s: [String] = []
        if contains(.fn) { s.append("fn") }
        if contains(.control) { s.append("⌃") }
        if contains(.option) { s.append("⌥") }
        if contains(.shift) { s.append("⇧") }
        if contains(.command) { s.append("⌘") }
        return s
    }
}

struct KeyCombo: Codable, Hashable {
    var mods: Mods
    /// Display form of the key: "N", "←", "⌫", "⇥", "F2", "Space".
    var key: String

    init(_ mods: Mods, _ key: String) {
        self.mods = mods
        self.key = key
    }

    var keycaps: [String] { mods.symbols + [key] }
    var display: String { keycaps.joined() }

    private var isLetterOrDigit: Bool {
        key.count == 1 && key.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
    }

    /// Keys used to match a keystroke against a hint. Punctuation shortcuts like ⌘? are typed with ⇧,
    /// so for non-alphanumeric keys a shift-less variant is accepted too.
    var matchKeys: [String] {
        let base = mods.subtracting(.fn)
        let k = key.uppercased()
        var keys = ["\(base.rawValue)|\(k)"]
        if !isLetterOrDigit, base.contains(.shift) {
            keys.append("\(base.subtracting(.shift).rawValue)|\(k)")
        }
        return keys
    }

    /// Parses strings like "⇧⌘N", "fn⌃F", "⌃⌘Space" into a combo.
    static func parse(_ s: String) -> KeyCombo {
        let caps = keycaps(from: s)
        var mods: Mods = []
        for c in caps.dropLast() {
            switch c {
            case "⌃": mods.insert(.control)
            case "⌥": mods.insert(.option)
            case "⇧": mods.insert(.shift)
            case "⌘": mods.insert(.command)
            case "fn", "🌐": mods.insert(.fn)
            default: break
            }
        }
        return KeyCombo(mods, caps.last ?? s)
    }

    /// Splits "⇧⌘N" into ["⇧", "⌘", "N"] for keycap rendering.
    static func keycaps(from s: String) -> [String] {
        var caps: [String] = []
        var rest = Substring(s)
        while rest.count > 1 {
            if rest.hasPrefix("fn") {
                caps.append("fn")
                rest = rest.dropFirst(2)
            } else if let f = rest.first, "⌃⌥⇧⌘🌐".contains(f) {
                caps.append(String(f))
                rest = rest.dropFirst()
            } else {
                break
            }
        }
        if !rest.isEmpty { caps.append(String(rest)) }
        return caps
    }

    /// Builds a combo from a key event. Main thread only: NSEvent consults the keyboard layout.
    static func from(event: CGEvent) -> KeyCombo {
        let mods = Mods(event.flags)
        let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
        if let name = KeyNames.byKeyCode[code] { return KeyCombo(mods, name) }
        let chars = NSEvent(cgEvent: event)?.charactersIgnoringModifiers ?? ""
        return KeyCombo(mods, KeyNames.display(forCharacter: chars))
    }
}

enum KeyNames {
    static let byKeyCode: [Int: String] = [
        36: "↩", 76: "⌤", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 117: "⌦",
        115: "Home", 119: "End", 116: "PgUp", 121: "PgDn",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
    ]

    /// US-layout key codes, for shortcuts stored as raw key codes (system hotkeys, Raycast).
    static let ansiLetters: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q",
        13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
        24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I",
        35: "P", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M",
        47: ".", 50: "`",
    ]

    /// Classic Carbon menu glyph codes (kMenu*Glyph) reported by AXMenuItemCmdGlyph.
    static let glyphs: [Int: String] = {
        var g: [Int: String] = [
            0x02: "⇥", 0x03: "⇤", 0x04: "⌤", 0x09: "Space", 0x0A: "⌦", 0x0B: "↩", 0x0C: "↩", 0x0D: "↩",
            0x10: "↓", 0x17: "⌫", 0x18: "←", 0x19: "↑", 0x1A: "→", 0x1B: "⎋", 0x1C: "⌧",
            0x62: "PgUp", 0x63: "⇪", 0x64: "←", 0x65: "→", 0x66: "Home", 0x67: "Help", 0x68: "↑",
            0x69: "End", 0x6A: "↓", 0x6B: "PgDn", 0x6E: "⏻", 0x8C: "⏏",
            0x87: "F13", 0x88: "F14", 0x89: "F15", 0x8F: "F16", 0x90: "F17", 0x91: "F18", 0x92: "F19",
        ]
        for i in 0..<12 { g[0x6F + i] = "F\(i + 1)" }
        return g
    }()

    /// Display name for a key character: letters upper-cased, special keys named.
    static func display(forCharacter s: String) -> String {
        let k = forCharacter(s)
        return k.count == 1 ? k.uppercased() : k
    }

    /// Maps NSEvent / NSMenuItem key-equivalent characters (incl. private-use function keys) to display names.
    static func forCharacter(_ s: String) -> String {
        guard let scalar = s.unicodeScalars.first, s.unicodeScalars.count == 1 else { return s }
        switch scalar.value {
        case 0x0D, 0x0A: return "↩"
        case 0x03: return "⌤"
        case 0x09: return "⇥"
        case 0x19: return "⇤"
        case 0x20: return "Space"
        case 0x08, 0x7F: return "⌫"
        case 0x1B: return "⎋"
        case 0xF700: return "↑"
        case 0xF701: return "↓"
        case 0xF702: return "←"
        case 0xF703: return "→"
        case 0xF704...0xF726: return "F\(scalar.value - 0xF704 + 1)"
        case 0xF728: return "⌦"
        case 0xF729: return "Home"
        case 0xF72B: return "End"
        case 0xF72C: return "PgUp"
        case 0xF72D: return "PgDn"
        default: return s
        }
    }
}
