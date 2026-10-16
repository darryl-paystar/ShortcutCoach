import AppKit
import ApplicationServices

/// Turns raw input events into hints. Runs on the event-tap thread: anything that must see UI
/// before the click lands (menus, window buttons, dialogs) is checked synchronously; the rest
/// moves to a background queue. Hints are handed to `Coach` on the main thread.
final class Detector {
    private let background = DispatchQueue(label: "ShortcutCoach.detect", qos: .userInitiated)

    // Tap-thread state
    private var mouseDownAt: CGPoint?
    private var repeatKey = -1
    private var repeatShift = false
    private var repeatCount = 0
    private var repeatLast = Date.distantPast
    private var repeatFired = false
    private var finderReturnAt: Date?

    func handle(_ type: CGEventType, _ event: CGEvent) {
        switch type {
        case .leftMouseDown, .rightMouseDown:
            mouseDownAt = event.location
            Coach.userActivity()
        case .leftMouseUp, .rightMouseUp:
            if Prefs.enabled { mouseUp(at: event.location) }
            mouseDownAt = nil
        case .keyDown:
            Coach.userActivity()
            if Prefs.enabled { keyDown(event) }
        case .flagsChanged:
            Coach.flagsChanged(Mods(event.flags))
        default:
            break
        }
    }

    private func post(_ hint: Hint) {
        DispatchQueue.main.async { Coach.shared.show(hint) }
    }

    // MARK: - Mouse

    private func mouseUp(at p: CGPoint) {
        let moved = mouseDownAt.map { hypot($0.x - p.x, $0.y - p.y) > 6 } ?? false

        // Decide whether it's safe and useful to hit-test before touching Accessibility. The hit test is
        // scoped to the app that owns the window under the cursor, so our own windows are never queried.
        guard let win = WindowList.window(at: p), win.pid != Apps.ownPID else { return }
        do {
            if win.layer == 0 {
                if moved { return }
                let info = Apps.info(pid: win.pid)
                let dx = p.x - win.bounds.minX, dy = p.y - win.bounds.minY
                switch info.engine {
                case .native: break
                // Chromium's tab strip / toolbar are native views; web content would switch on
                // Chrome's (expensive) accessibility mode, so never hit-test below the toolbar.
                // The collapsed vertical tab strip (56 pt) is native too.
                case .chromium: if dy > 96 && dx > 56 { return }
                // Electron / Firefox chrome is web content too: traffic lights only.
                case .webShell: if dy > 40 || dx > 100 { return }
                }
            }
        }

        guard let el = AX.element(at: p, pid: win.pid) else { return }
        let app = Apps.info(pid: el.pid)
        guard app.pid != Apps.ownPID, !Prefs.isIgnored(app.bundleID) else { return }
        if Prefs.debugLogging {
            Log.debug("click app=\(app.bundleID ?? "?") role=\(el.role ?? "-") sub=\(el.subrole ?? "-") label=\(el.label ?? "-") id=\(el.identifier ?? "-")")
        }

        // "Apple apps and macOS only": third-party apps get only the system-wide window & dialog hints.
        let inScope = app.isApple || !Prefs.on(Prefs.Key.appleAppsOnly)

        // Synchronous checks: this UI is gone once the click is delivered.
        if let item = el.ancestor(maxDepth: 2, where: { $0.role == kAXMenuItemRole }) {
            guard inScope else { return }
            menuItem(item, app: app)
            return
        }
        if moved { return }
        if app.bundleID == "com.apple.dock" { dock(el); return }
        if windowControl(el) { return }
        if dialogButton(el) { return }
        guard inScope else { return }

        // Everything else survives the click, so do the heavier lookups off the tap thread.
        background.async { [self] in
            if app.isBrowser, browser(el, app: app) { return }
            if app.isFinder || app.bundleID == "com.apple.Terminal" || app.bundleID == "com.googlecode.iterm2",
               tabClick(el, app: app, isBrowser: false) { return }
            if app.isFinder, finderSidebar(el, app: app) { return }
            if searchField(el, app: app) { return }
            genericButton(el, app: app)
        }
    }

    private func menuItem(_ item: AXUIElement, app: AppInfo) {
        let v = item.values(MenuIndex.itemAttributes)
        guard let title = v[kAXTitleAttribute] as? String, !title.isEmpty else { return }
        if let enabled = v[kAXEnabledAttribute] as? NSNumber, !enabled.boolValue { return }
        if let kids = v[kAXChildrenAttribute] as? [AXUIElement], !kids.isEmpty { return } // submenu parent

        let combo = MenuIndex.combo(char: v["AXMenuItemCmdChar"] as? String,
                                    modifiers: (v["AXMenuItemCmdModifiers"] as? NSNumber)?.intValue,
                                    glyph: (v["AXMenuItemCmdGlyph"] as? NSNumber)?.intValue)
        if let combo {
            guard Prefs.on(Prefs.Key.hintMenus) else { return }
            post(Hint(id: Self.actionID(app, title), kind: .menu, bundleID: app.bundleID, appName: app.name,
                      title: title, combos: [combo]))
        } else if Prefs.on(Prefs.Key.suggestCustomShortcuts), Apps.front?.pid == app.pid,
                  let path = menuBarPath(of: item) {
            let full = path + [title]
            DispatchQueue.main.async { Coach.shared.menuItemWithoutShortcut(app: app, path: full) }
        }
    }

    /// Titles of the parent menus when `item` lives in the app's main menu bar; nil for context and status menus.
    private func menuBarPath(of item: AXUIElement) -> [String]? {
        var path: [String] = []
        var cur = item.parent
        for _ in 0..<10 {
            guard let c = cur, let role = c.role else { return nil }
            if role == kAXMenuBarItemRole {
                guard c.subrole != "AXMenuExtra", let t = c.title else { return nil }
                return [t] + path
            }
            if role == kAXMenuItemRole, let t = c.title { path.insert(t, at: 0) }
            cur = c.parent
        }
        return nil
    }

    private func dock(_ el: AXUIElement) {
        guard Prefs.on(Prefs.Key.hintDock),
              let item = el.ancestor(maxDepth: 2, where: { $0.role == "AXDockItem" }),
              item.subrole == "AXApplicationDockItem", let name = item.title else { return }
        if item.bool("AXIsApplicationRunning") ?? false {
            let altTab = Apps.isRunning("com.lwouis.alt-tab-macos")
            post(Hint(id: "dock|switch", kind: .dock, bundleID: nil, appName: "All apps", title: "Switch to \(name)",
                      combos: [KeyCombo([.command], "⇥")] + (altTab ? [KeyCombo([.option], "⇥")] : []),
                      display: [["⌘", "⇥"]],
                      message: "Hold ⌘ and tap ⇥ to pick an app; release to switch. ⌘` cycles windows of the current app."
                          + (altTab ? " AltTab's shortcut counts too." : ""),
                      symbol: "dock.rectangle"))
        } else if let launcher = SystemHotkeys.launcher {
            // Uses the real binding: Spotlight's shortcut may be remapped or handed over to Raycast.
            post(Hint(id: "dock|launch", kind: .dock, bundleID: nil, appName: "All apps", title: "Open \(name)",
                      combos: [launcher.combo],
                      message: "\(launcher.combo.display) opens \(launcher.name): type a few letters of “\(name)” and press ↩.",
                      symbol: "magnifyingglass"))
        }
    }

    private static let windowButtonSubroles: Set<String> = ["AXCloseButton", "AXMinimizeButton", "AXFullScreenButton", "AXZoomButton"]

    private func windowControl(_ el: AXUIElement) -> Bool {
        guard let btn = el.ancestor(maxDepth: 1, where: { Self.windowButtonSubroles.contains($0.subrole ?? "") }) else { return false }
        guard Prefs.on(Prefs.Key.hintWindowControls) else { return true }
        let hint: Hint
        switch btn.subrole {
        case "AXCloseButton":
            hint = Hint(id: "window|close", kind: .window, bundleID: nil, appName: "All apps", title: "Close Window",
                        combos: [KeyCombo([.command], "W")],
                        message: "Closing the last window usually leaves the app running — ⌘Q quits it. ⌥⌘W closes all of its windows.",
                        symbol: "xmark.circle")
        case "AXMinimizeButton":
            hint = Hint(id: "window|minimize", kind: .window, bundleID: nil, appName: "All apps", title: "Minimize Window",
                        combos: [KeyCombo([.command], "M")],
                        message: "Often better: ⌘H hides the whole app (⌘⇥ brings it back). ⌥⌘H hides every other app.",
                        symbol: "minus.circle")
        case "AXFullScreenButton":
            hint = Hint(id: "window|fullscreen", kind: .window, bundleID: nil, appName: "All apps", title: "Enter Full Screen",
                        combos: [KeyCombo([.control, .command], "F")],
                        message: "To tile instead: fn⌃← / fn⌃→ snap to halves, fn⌃F fills the screen, fn⌃R restores. ⌥-click the green button to zoom.",
                        symbol: "arrow.up.left.and.arrow.down.right")
        default:
            hint = Hint(id: "window|zoom", kind: .window, bundleID: nil, appName: "All apps", title: "Fill the Screen",
                        combos: [KeyCombo([.fn, .control], "F")],
                        message: "fn⌃← / fn⌃→ snap to halves; fn⌃R restores the previous size.",
                        symbol: "rectangle.inset.filled")
        }
        post(hint)
        return true
    }

    private func dialogButton(_ el: AXUIElement) -> Bool {
        guard Prefs.on(Prefs.Key.hintDialogs),
              let btn = el.ancestor(maxDepth: 1, where: { $0.role == kAXButtonRole }) else { return false }
        let containers = [btn.element("AXTopLevelUIElement"), btn.element(kAXWindowAttribute)].compactMap { $0 }
        for c in containers {
            if let def = c.element(kAXDefaultButtonAttribute), CFEqual(def, btn) {
                post(Hint(id: "dialog|default", kind: .dialog, bundleID: nil, appName: "All apps",
                          title: "Press “\(btn.label ?? "OK")”", combos: [KeyCombo([], "↩")],
                          message: "↩ Return clicks the highlighted (blue) button in any dialog. ⎋ Esc cancels.",
                          symbol: "return", trackUsage: false))
                return true
            }
            if let cancel = c.element(kAXCancelButtonAttribute), CFEqual(cancel, btn) {
                post(Hint(id: "dialog|cancel", kind: .dialog, bundleID: nil, appName: "All apps",
                          title: "Cancel", combos: [KeyCombo([], "⎋")],
                          message: "⎋ Esc (or ⌘.) cancels almost any dialog or sheet.",
                          symbol: "escape", trackUsage: false))
                return true
            }
        }
        return false
    }

    // MARK: Background click rules

    private func browser(_ el: AXUIElement, app: AppInfo) -> Bool {
        guard Prefs.on(Prefs.Key.hintBrowser) else { return false }
        let role = el.role ?? ""
        if role == kAXTextFieldRole || role == kAXComboBoxRole {
            let hay = [el.identifier, el.axDescription, el.title, el.placeholder]
                .compactMap { $0?.lowercased() }.joined(separator: " ")
            if el.identifier == "WEB_BROWSER_ADDRESS_AND_SEARCH_FIELD" || hay.contains("address")
                || hay.contains("search or enter") || hay.contains("search or type") {
                post(Hint(id: Self.actionID(app, "address-bar"), kind: .browser, bundleID: app.bundleID, appName: app.name,
                          title: "Jump to the address bar", combos: [KeyCombo([.command], "L")],
                          message: "Type a URL or search and press ↩. ⌘T opens a new tab with the address bar ready.",
                          symbol: "link"))
                return true
            }
        }
        return tabClick(el, app: app, isBrowser: true)
    }

    private func tabClick(_ el: AXUIElement, app: AppInfo, isBrowser: Bool) -> Bool {
        // Only real tabs (Safari, Chrome incl. vertical tabs, Finder all use AXTabButton). The surrounding
        // AXTabGroup also holds buttons like Chrome's "Tab groups" / "Expand Tabs", which aren't tab switches.
        // Close / new-tab buttons are left to the generic button matcher.
        if el.role == kAXButtonRole { return false }
        guard el.ancestor(maxDepth: 2, where: { $0.subrole == "AXTabButton" }) != nil else { return false }
        guard Prefs.on(isBrowser ? Prefs.Key.hintBrowser : Prefs.Key.hintFinder) else { return true }

        // ⇧⌘] is reported as ⌘} by the keyboard, so match the shifted characters.
        let cycle = [KeyCombo([.control], "⇥"), KeyCombo([.control, .shift], "⇥"),
                     KeyCombo([.command], "}"), KeyCombo([.command], "{")]
        if isBrowser {
            let numbers = (1...9).map { KeyCombo([.command], "\($0)") }
            post(Hint(id: Self.actionID(app, "switch-tabs"), kind: .browser, bundleID: app.bundleID, appName: app.name,
                      title: "Switch tabs", combos: numbers + cycle + [KeyCombo([.option, .command], "←"), KeyCombo([.option, .command], "→")],
                      display: [["⌘", "1…9"], ["⌃", "⇥"]],
                      message: "⌘1–⌘8 jump straight to that tab, ⌘9 to the last one. ⌃⇥ / ⌃⇧⇥ cycle forward and back.",
                      symbol: "rectangle.stack"))
        } else {
            post(Hint(id: Self.actionID(app, "switch-tabs"), kind: .finder, bundleID: app.bundleID, appName: app.name,
                      title: "Switch tabs", combos: cycle, display: [["⌃", "⇥"], ["⇧", "⌘", "]"]],
                      message: "⌃⇥ / ⌃⇧⇥ cycle tabs (⇧⌘] / ⇧⌘[ too). ⌘T opens a new tab.",
                      symbol: "rectangle.stack"))
        }
        return true
    }

    private func finderSidebar(_ el: AXUIElement, app: AppInfo) -> Bool {
        guard let row = el.ancestor(maxDepth: 3, where: { $0.role == kAXRowRole }),
              let outline = row.parent, outline.role == kAXOutlineRole,
              outline.axDescription?.lowercased() == "sidebar" else { return false }
        guard Prefs.on(Prefs.Key.hintFinder), var label = Self.firstText(in: row) else { return true }
        if label == NSUserName() { label = "Home" }
        let shown = label
        MenuIndex.shared.lookup(pid: app.pid, titles: [label]) { [self] hit in
            guard let hit, let combo = hit.combo else { return }
            post(Hint(id: Self.actionID(app, hit.title), kind: .finder, bundleID: app.bundleID, appName: app.name,
                      title: "Go to \(shown)", combos: [combo],
                      message: "Works from any Finder window — and inside Open / Save dialogs.",
                      symbol: "folder"))
        }
        return true
    }

    private func searchField(_ el: AXUIElement, app: AppInfo) -> Bool {
        guard el.ancestor(maxDepth: 1, where: { $0.subrole == "AXSearchField" }) != nil else { return false }
        guard Prefs.on(Prefs.Key.hintButtons), app.engine == .native, !app.isBrowser else { return true }
        MenuIndex.shared.lookup(pid: app.pid, titles: ["Find", "Search"]) { [self] hit in
            guard let hit, let combo = hit.combo else { return }
            post(Hint(id: Self.actionID(app, hit.title), kind: .button, bundleID: app.bundleID, appName: app.name,
                      title: "Search", combos: [combo], symbol: "magnifyingglass"))
        }
        return true
    }

    private static let aliasTable: [String: [String]] = [
        "reload": ["Reload This Page", "Reload Page"],
        "refresh": ["Reload This Page", "Reload Page", "Reload"],
        "icon view": ["as Icons"], "list view": ["as List"], "column view": ["as Columns"], "gallery view": ["as Gallery"],
        "create a new tab": ["New Tab"], "open a new tab": ["New Tab"],
        "show sidebar": ["Hide Sidebar", "Toggle Sidebar"], "hide sidebar": ["Show Sidebar", "Toggle Sidebar"],
        "sidebar": ["Show Sidebar", "Hide Sidebar", "Toggle Sidebar"], "toggle sidebar": ["Show Sidebar", "Hide Sidebar"],
        "compose": ["New Message"], "trash": ["Move to Trash", "Delete"], "delete": ["Move to Trash"],
        "bookmark": ["Bookmark This Tab", "Add Bookmark"],
    ]

    private func genericButton(_ el: AXUIElement, app: AppInfo) {
        guard Prefs.on(Prefs.Key.hintButtons),
              let btn = el.ancestor(maxDepth: 1, where: { [kAXButtonRole, kAXRadioButtonRole, kAXCheckBoxRole].contains($0.role ?? "") })
        else { return }
        let inToolbar = btn.ancestor(maxDepth: 4, where: { $0.role == kAXToolbarRole }) != nil
        if btn.role != kAXButtonRole, !inToolbar { return }
        guard let label = btn.label, label.count <= 40 else { return }
        // Skip buttons inside web pages (the page's UI, not the app's) and inside sheets/dialogs.
        if app.engine == .native, btn.ancestor(maxDepth: 15, where: { $0.role == "AXWebArea" }) != nil { return }
        if btn.element("AXTopLevelUIElement")?.role == kAXSheetRole { return }

        let titles = [label] + (Self.aliasTable[MenuIndex.normalize(label)] ?? [])
        MenuIndex.shared.lookup(pid: app.pid, titles: titles) { [self] hit in
            guard let hit, let combo = hit.combo else { return }
            post(Hint(id: Self.actionID(app, hit.title), kind: .button, bundleID: app.bundleID, appName: app.name,
                      title: hit.title, combos: [combo], symbol: "cursorarrow.click"))
        }
    }

    // MARK: - Keyboard

    private func keyDown(_ event: CGEvent) {
        guard let app = Apps.front, app.pid != Apps.ownPID, !Prefs.isIgnored(app.bundleID) else { return }
        let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let mods = Mods(flags)
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        if !mods.isEmpty, mods != [.shift], !isRepeat, let copy = event.copy() {
            // Turning a key code into a character consults the keyboard layout (TSM), which macOS only
            // allows on the main thread — so this part runs there, on a copy of the event.
            DispatchQueue.main.async { [self] in
                let combo = KeyCombo.from(event: copy)
                Coach.shared.comboTyped(combo, bundleID: app.bundleID)
                if Prefs.on(Prefs.Key.hintWindowsHabits), !Prefs.isHabitExcluded(app.bundleID) {
                    windowsHabit(combo: combo, code: code, mods: mods, fnHeld: flags.contains(.maskSecondaryFn), app: app)
                }
            }
        }
        navigationKeys(code: code, mods: mods, isRepeat: isRepeat, app: app)
    }

    private struct CtrlHabit {
        let action: String
        let mac: KeyCombo
        let extra: String?
    }

    private static let ctrlHabits: [String: CtrlHabit] = [
        "C": CtrlHabit(action: "Copy", mac: KeyCombo([.command], "C"), extra: nil),
        "V": CtrlHabit(action: "Paste", mac: KeyCombo([.command], "V"), extra: "⌥⇧⌘V pastes without formatting."),
        "X": CtrlHabit(action: "Cut", mac: KeyCombo([.command], "X"), extra: nil),
        "Z": CtrlHabit(action: "Undo", mac: KeyCombo([.command], "Z"), extra: "Redo is ⇧⌘Z."),
        "Y": CtrlHabit(action: "Redo", mac: KeyCombo([.shift, .command], "Z"), extra: nil),
        "S": CtrlHabit(action: "Save", mac: KeyCombo([.command], "S"), extra: nil),
        "A": CtrlHabit(action: "Select All", mac: KeyCombo([.command], "A"), extra: "Bonus: ⌃A / ⌃E jump to the start / end of a line in Mac text fields."),
        "F": CtrlHabit(action: "Find", mac: KeyCombo([.command], "F"), extra: "⌘G jumps to the next match."),
        "W": CtrlHabit(action: "Close", mac: KeyCombo([.command], "W"), extra: "⌘Q quits the app."),
        "T": CtrlHabit(action: "New Tab", mac: KeyCombo([.command], "T"), extra: "⇧⌘T reopens the last closed tab."),
        "R": CtrlHabit(action: "Reload", mac: KeyCombo([.command], "R"), extra: nil),
    ]

    private func windowsHabit(combo: KeyCombo, code: Int, mods: Mods, fnHeld: Bool, app: AppInfo) {
        func habit(_ id: String, _ title: String, _ combos: [KeyCombo], windows: String, extra: String?, display: [[String]]? = nil) {
            post(Hint(id: "habit|\(id)", kind: .habit, bundleID: nil, appName: "Windows habit", title: title,
                      combos: combos, display: display, eyebrow: "Windows habit · \(windows)",
                      message: extra, symbol: "arrow.left.arrow.right"))
        }

        switch mods {
        case [.control]:
            var letter = Self.ctrlHabits[combo.key]
            if letter == nil, combo.key == "L", app.isBrowser {
                letter = CtrlHabit(action: "Address Bar", mac: KeyCombo([.command], "L"), extra: nil)
            }
            if let h = letter, !fnHeld {
                // The app may genuinely bind ⌃<key> in its menus; then it isn't a habit.
                if let entry = MenuIndex.shared.cached(pid: app.pid), combo.matchKeys.contains(where: entry.comboKeys.contains) { return }
                let base = "On a Mac, ⌘ Command does most of what Ctrl did on Windows."
                habit("ctrl-\(combo.key)", h.action, [h.mac], windows: "Ctrl+\(combo.key)",
                      extra: h.extra.map { base + " " + $0 } ?? base)
                return
            }
            switch code {
            case 123, 124:
                whenTextFocused(app) {
                    habit("ctrl-arrow", "Jump word by word", [KeyCombo([.option], "←"), KeyCombo([.option], "→")],
                          windows: "Ctrl+←/→", extra: "On a Mac, ⌃← / ⌃→ switch desktops (Spaces). ⌘← / ⌘→ go to line start / end.")
                }
            case 51:
                habit("ctrl-backspace", "Delete the previous word", [KeyCombo([.option], "⌫")], windows: "Ctrl+Backspace",
                      extra: "⌘⌫ deletes to the start of the line.")
            case 117:
                habit("ctrl-delete", "Delete the next word", [KeyCombo([.option], "⌦")], windows: "Ctrl+Delete",
                      extra: "No ⌦ key? On laptops it's fn⌫, so this is ⌥fn⌫.")
            case 115:
                habit("ctrl-home", "Top of the document", [KeyCombo([.command], "↑")], windows: "Ctrl+Home", extra: nil)
            case 119:
                habit("ctrl-end", "End of the document", [KeyCombo([.command], "↓")], windows: "Ctrl+End", extra: nil)
            default:
                break
            }
        case [.control, .shift]:
            if code == 123 || code == 124 {
                whenTextFocused(app) {
                    habit("ctrl-shift-arrow", "Select word by word", [KeyCombo([.option, .shift], "←"), KeyCombo([.option, .shift], "→")],
                          windows: "Ctrl+Shift+←/→", extra: "⇧⌘← / ⇧⌘→ select to the start / end of the line.")
                }
            } else if code == 53 {
                habit("ctrl-shift-esc", "Force Quit", [KeyCombo([.option, .command], "⎋")], windows: "Ctrl+Shift+Esc",
                      extra: "For the full “Task Manager”, open Activity Monitor (⌘Space → Activity).")
            }
        case [.option]:
            if code == 118 {
                habit("alt-f4", "Quit the app", [KeyCombo([.command], "Q")], windows: "Alt+F4", extra: "⌘W only closes the window.")
            } else if code == 48, !Apps.isRunning("com.lwouis.alt-tab-macos") {
                habit("alt-tab", "Switch apps", [KeyCombo([.command], "⇥")], windows: "Alt+Tab", extra: "⌘` cycles windows of the same app.")
            }
        case [.control, .option] where code == 117:
            habit("ctrl-alt-del", "Force Quit", [KeyCombo([.option, .command], "⎋")], windows: "Ctrl+Alt+Delete", extra: nil)
        default:
            break
        }
    }

    private func navigationKeys(code: Int, mods: Mods, isRepeat: Bool, app: AppInfo) {
        let now = Date()
        let plainOrShift = mods.isEmpty || mods == [.shift]

        // Repeated arrows / backspace → teach word & line jumps.
        if plainOrShift, [123, 124, 125, 126, 51].contains(code) {
            let shift = mods.contains(.shift)
            if code == repeatKey, shift == repeatShift, now.timeIntervalSince(repeatLast) < 1.0 {
                repeatCount += 1
            } else {
                repeatKey = code
                repeatShift = shift
                repeatCount = 1
                repeatFired = false
            }
            repeatLast = now
            let threshold = (code == 125 || code == 126) ? 15 : 8
            if repeatCount >= threshold, !repeatFired {
                repeatFired = true
                if Prefs.on(Prefs.Key.hintTextEditing), !Prefs.isHabitExcluded(app.bundleID), !app.isFinder {
                    whenTextFocused(app) { [self] in repetitionHint(code: code, shift: shift) }
                }
            }
        } else {
            repeatKey = -1
        }

        guard plainOrShift else { return }
        // Note: a `where` clause only binds to the last pattern of a case, so conditions live in guards.
        switch code {
        case 115, 119: // Home / End
            guard !isRepeat, app.engine == .native, Prefs.on(Prefs.Key.hintTextEditing),
                  !Prefs.isHabitExcluded(app.bundleID) else { return }
            let shift = mods.contains(.shift)
            whenTextFocused(app) { [self] in
                post(Hint(id: "text|home-end", kind: .text, bundleID: nil, appName: "Text editing",
                          title: shift ? "Select to line start / end" : "Line start / end",
                          combos: shift ? [KeyCombo([.shift, .command], "←"), KeyCombo([.shift, .command], "→")]
                                        : [KeyCombo([.command], "←"), KeyCombo([.command], "→")],
                          eyebrow: "Windows habit · Home / End",
                          message: "On a Mac, Home / End scroll without moving the cursor. ⌘↑ / ⌘↓ jump to the top / bottom.",
                          symbol: "text.cursor"))
            }
        case 120 where app.isFinder && mods.isEmpty: // F2
            guard Prefs.on(Prefs.Key.hintFinder) else { return }
            post(Hint(id: "finder|rename", kind: .finder, bundleID: "com.apple.finder", appName: "Finder",
                      title: "Rename", combos: [KeyCombo([], "↩")], eyebrow: "Windows habit · F2",
                      message: "Select a file and press ↩ Return to rename it.", symbol: "pencil", trackUsage: false))
        case 36 where app.isFinder && mods.isEmpty && !isRepeat:
            finderReturnAt = now
        case 53 where app.isFinder && mods.isEmpty:
            // Return (expecting "open") then Esc to back out of the rename it started.
            if let t = finderReturnAt, now.timeIntervalSince(t) < 4, Prefs.on(Prefs.Key.hintFinder) {
                post(Hint(id: "finder|open", kind: .finder, bundleID: "com.apple.finder", appName: "Finder",
                          title: "Open the selected item", combos: [KeyCombo([.command], "↓"), KeyCombo([.command], "O")],
                          eyebrow: "Windows habit · Enter to open",
                          message: "In Finder, ↩ Return renames. ⌘↓ opens; ⌘↑ goes up to the enclosing folder.",
                          symbol: "folder"))
            }
            finderReturnAt = nil
        case 51, 117:
            guard app.isFinder, mods.isEmpty, !isRepeat, Prefs.on(Prefs.Key.hintFinder) else { return }
            background.async { [self] in
                guard !AX.isTextFocused(pid: app.pid) else { return }
                post(Hint(id: "finder|trash", kind: .finder, bundleID: "com.apple.finder", appName: "Finder",
                          title: "Move to Trash", combos: [KeyCombo([.command], "⌫")],
                          eyebrow: "Windows habit · Delete",
                          message: "⌘Z puts it back. Wanted to go up a folder? That's ⌘↑ (⌘[ goes back).",
                          symbol: "trash"))
            }
        default:
            break
        }
    }

    private func repetitionHint(code: Int, shift: Bool) {
        let hint: Hint
        switch code {
        case 123, 124:
            if shift {
                post(Hint(id: "text|select-word", kind: .text, bundleID: nil, appName: "Text editing", title: "Select word by word",
                          combos: [KeyCombo([.option, .shift], "←"), KeyCombo([.option, .shift], "→")],
                          eyebrow: "Faster than holding an arrow",
                          message: "⇧⌘← / ⇧⌘→ select to the start / end of the line.", symbol: "text.cursor"))
                return
            }
            hint = Hint(id: "text|word-jump", kind: .text, bundleID: nil, appName: "Text editing", title: "Jump word by word",
                        combos: [KeyCombo([.option], "←"), KeyCombo([.option], "→")],
                        eyebrow: "Faster than holding an arrow",
                        message: "⌘← / ⌘→ jump to the start / end of the line. Add ⇧ to select.", symbol: "text.cursor")
        case 125, 126:
            hint = Hint(id: "text|doc-jump", kind: .text, bundleID: nil, appName: "Text editing", title: "Jump to top / bottom",
                        combos: [KeyCombo([.command], "↑"), KeyCombo([.command], "↓")],
                        eyebrow: "Faster than holding an arrow",
                        message: "⌥↑ / ⌥↓ move by paragraph in most editors; fn↑ / fn↓ are Page Up / Down.", symbol: "arrow.up.and.down")
        default:
            hint = Hint(id: "text|delete-word", kind: .text, bundleID: nil, appName: "Text editing", title: "Delete a word at a time",
                        combos: [KeyCombo([.option], "⌫"), KeyCombo([.command], "⌫")], display: [["⌥", "⌫"]],
                        eyebrow: "Faster than tapping ⌫",
                        message: "⌘⌫ deletes to the start of the line; fn⌫ deletes forward.", symbol: "delete.left")
        }
        post(hint)
    }

    /// Runs `body` only if the app's focused element is editable text. Web-based apps are assumed to be
    /// (asking them would switch on their costly accessibility mode).
    private func whenTextFocused(_ app: AppInfo, _ body: @escaping () -> Void) {
        guard app.engine == .native else { body(); return }
        background.async {
            if AX.isTextFocused(pid: app.pid) { body() }
        }
    }

    // MARK: - Helpers

    static func actionID(_ app: AppInfo, _ action: String) -> String {
        "\(app.bundleID ?? app.name)|\(action)"
    }

    static func firstText(in el: AXUIElement, depth: Int = 0) -> String? {
        if el.role == kAXStaticTextRole, let v = el.stringValue { return v }
        guard depth < 3 else { return nil }
        for c in el.children {
            if let t = firstText(in: c, depth: depth + 1) { return t }
        }
        return nil
    }
}
