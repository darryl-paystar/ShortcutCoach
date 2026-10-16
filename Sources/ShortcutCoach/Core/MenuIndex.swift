import AppKit
import ApplicationServices

struct MenuShortcut: Identifiable, Hashable {
    /// Full path including the top-level menu, e.g. ["View", "Sort By", "Name"].
    let path: [String]
    let combo: KeyCombo?

    var id: String { path.joined(separator: "▸") + "|" + (combo?.display ?? "") }
    var title: String { path.last ?? "" }
    var menu: String { path.first ?? "" }
    /// Path below the top-level menu, e.g. "Sort By ▸ Name".
    var subpath: String { path.dropFirst().joined(separator: " ▸ ") }
}

/// Reads an app's whole menu bar through Accessibility, off the main thread, with a per-process cache.
final class MenuIndex {
    static let shared = MenuIndex()
    static let maxAge: TimeInterval = 120

    struct Entry {
        let items: [MenuShortcut]
        /// Normalized title → first menu item with that title that has a shortcut.
        let byTitle: [String: MenuShortcut]
        /// Match keys of every shortcut the app defines (used to avoid flagging app-specific ⌃ shortcuts).
        let comboKeys: Set<String>
        let date: Date
    }

    private let queue = DispatchQueue(label: "ShortcutCoach.menus", qos: .utility)
    private let lock = NSLock()
    private var cache: [pid_t: Entry] = [:]
    private var waiting: [pid_t: [(Entry) -> Void]] = [:]

    func cached(pid: pid_t) -> Entry? {
        lock.lock()
        defer { lock.unlock() }
        return cache[pid]
    }

    func forget(_ pid: pid_t) {
        lock.lock()
        cache[pid] = nil
        lock.unlock()
    }

    func refresh(pid: pid_t, force: Bool = false) {
        entry(pid: pid, maxAge: force ? 0 : Self.maxAge) { _ in }
    }

    /// Calls `completion` with a fresh-enough entry — synchronously on a cache hit, otherwise on a background queue.
    func entry(pid: pid_t, maxAge: TimeInterval = MenuIndex.maxAge, completion: @escaping (Entry) -> Void) {
        lock.lock()
        if let e = cache[pid], Date().timeIntervalSince(e.date) < maxAge {
            lock.unlock()
            completion(e)
            return
        }
        if waiting[pid] != nil {
            waiting[pid]!.append(completion)
            lock.unlock()
            return
        }
        waiting[pid] = [completion]
        lock.unlock()

        queue.async { [self] in
            let entry = Self.build(pid: pid)
            lock.lock()
            cache[pid] = entry
            let callbacks = waiting.removeValue(forKey: pid) ?? []
            lock.unlock()
            callbacks.forEach { $0(entry) }
        }
    }

    /// Finds the first of `titles` (normalized) that exists in the app's menus with a shortcut.
    func lookup(pid: pid_t, titles: [String], completion: @escaping (MenuShortcut?) -> Void) {
        entry(pid: pid) { e in
            for t in titles {
                if let hit = e.byTitle[Self.normalize(t)] { completion(hit); return }
            }
            completion(nil)
        }
    }

    static func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "…", with: "")
            .replacingOccurrences(of: "...", with: "")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    static func combo(char: String?, modifiers: Int?, glyph: Int?) -> KeyCombo? {
        let mods = Mods(axMenuModifiers: modifiers ?? 0)
        if let g = glyph, g > 0, let name = KeyNames.glyphs[g] { return KeyCombo(mods, name) }
        if let c = char, !c.isEmpty { return KeyCombo(mods, KeyNames.display(forCharacter: c)) }
        return nil
    }

    static let itemAttributes = [
        kAXRoleAttribute, kAXTitleAttribute, "AXMenuItemCmdChar", "AXMenuItemCmdModifiers",
        "AXMenuItemCmdGlyph", kAXEnabledAttribute, kAXChildrenAttribute,
    ]

    private static func build(pid: pid_t) -> Entry {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.5)
        var items: [MenuShortcut] = []
        if let bar = app.element(kAXMenuBarAttribute) {
            for top in bar.children {
                guard let title = top.title else { continue }
                for menu in top.children { walk(menu, path: [title], depth: 0, into: &items) }
            }
        }

        var seen = Set<String>()
        var unique: [MenuShortcut] = []
        var byTitle: [String: MenuShortcut] = [:]
        var comboKeys = Set<String>()
        for item in items {
            if let c = item.combo {
                comboKeys.formUnion(c.matchKeys)
                let key = normalize(item.title)
                if byTitle[key] == nil { byTitle[key] = item }
            }
            // Hidden ⌥ alternates repeat the same title; keep the first for display.
            if seen.insert(item.path.joined(separator: "▸")).inserted { unique.append(item) }
        }
        return Entry(items: unique, byTitle: byTitle, comboKeys: comboKeys, date: Date())
    }

    private static func walk(_ menu: AXUIElement, path: [String], depth: Int, into items: inout [MenuShortcut]) {
        guard depth < 4 else { return }
        for child in menu.children {
            let v = child.values(itemAttributes)
            guard (v[kAXRoleAttribute] as? String) == kAXMenuItemRole,
                  let title = v[kAXTitleAttribute] as? String, !title.isEmpty else { continue }
            let kids = (v[kAXChildrenAttribute] as? [AXUIElement]) ?? []
            if !kids.isEmpty {
                for sub in kids { walk(sub, path: path + [title], depth: depth + 1, into: &items) }
                continue
            }
            let combo = combo(char: v["AXMenuItemCmdChar"] as? String,
                              modifiers: (v["AXMenuItemCmdModifiers"] as? NSNumber)?.intValue,
                              glyph: (v["AXMenuItemCmdGlyph"] as? NSNumber)?.intValue)
            items.append(MenuShortcut(path: path + [title], combo: combo))
        }
    }
}
