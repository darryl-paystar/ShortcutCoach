import Foundation

/// A "you could have used a shortcut" event produced by a detector.
struct Hint {
    enum Kind: String, Codable {
        case menu, button, window, dialog, dock, browser, finder, habit, text, suggestion
    }

    /// Stable key for stats. Menu-item and toolbar hints for the same action share an id.
    var id: String
    var kind: Kind
    /// nil = applies everywhere (window buttons, Dock, habits).
    var bundleID: String?
    var appName: String
    var title: String
    var keycapGroups: [[String]]
    /// Keystrokes that count as "used the shortcut" for this hint.
    var matchCombos: [KeyCombo]
    var eyebrow = "Use the shortcut next time"
    var message: String?
    var symbol = "keyboard"

    init(id: String, kind: Kind, bundleID: String?, appName: String, title: String,
         combos: [KeyCombo], display: [[String]]? = nil, eyebrow: String = "Use the shortcut next time",
         message: String? = nil, symbol: String = "keyboard", trackUsage: Bool = true) {
        self.id = id
        self.kind = kind
        self.bundleID = bundleID
        self.appName = appName
        self.title = title
        self.keycapGroups = display ?? combos.map(\.keycaps)
        self.matchCombos = trackUsage ? combos : []
        self.eyebrow = eyebrow
        self.message = message
        self.symbol = symbol
    }
}

/// Persisted per-hint statistics (the "Key Promoter" counter).
struct HintRecord: Codable, Identifiable {
    var id: String
    var kind: Hint.Kind
    var bundleID: String?
    var appName: String
    var title: String
    var keycapGroups: [[String]]
    var matchKeys: [String]
    var shown: Int = 0
    var used: Int = 0
    var firstSeen = Date()
    var lastShown: Date?
    var lastUsed: Date?
    var muted = false
    /// You were already using this shortcut before the first hint, so it isn't something you learned here.
    var alreadyKnown = false
    /// Mouse uses in a row since the shortcut was last typed (drives "remind me again" for known shortcuts).
    var mouseStreak = 0

    static let learnedThreshold = 5
    /// Keystrokes before a shortcut's first hint that mark it as already known.
    static let knownBeforeThreshold = 3

    var isLearned: Bool { !alreadyKnown && used >= Self.learnedThreshold }
    /// Known either way: learned here, or already known before.
    var isKnown: Bool { alreadyKnown || isLearned }
    var progress: Double { alreadyKnown ? 1 : min(1, Double(used) / Double(Self.learnedThreshold)) }
}

extension HintRecord {
    // Tolerates stats files written before newer fields existed.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = try c.decode(Hint.Kind.self, forKey: .kind)
        bundleID = try c.decodeIfPresent(String.self, forKey: .bundleID)
        appName = try c.decode(String.self, forKey: .appName)
        title = try c.decode(String.self, forKey: .title)
        keycapGroups = try c.decode([[String]].self, forKey: .keycapGroups)
        matchKeys = try c.decodeIfPresent([String].self, forKey: .matchKeys) ?? []
        shown = try c.decodeIfPresent(Int.self, forKey: .shown) ?? 0
        used = try c.decodeIfPresent(Int.self, forKey: .used) ?? 0
        firstSeen = try c.decodeIfPresent(Date.self, forKey: .firstSeen) ?? Date()
        lastShown = try c.decodeIfPresent(Date.self, forKey: .lastShown)
        lastUsed = try c.decodeIfPresent(Date.self, forKey: .lastUsed)
        muted = try c.decodeIfPresent(Bool.self, forKey: .muted) ?? false
        alreadyKnown = try c.decodeIfPresent(Bool.self, forKey: .alreadyKnown) ?? false
        mouseStreak = try c.decodeIfPresent(Int.self, forKey: .mouseStreak) ?? 0
    }
}
