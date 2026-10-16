import SwiftUI

struct ShortcutEntry: Identifiable {
    let id = UUID()
    /// One or more alternatives, e.g. ["⌘["] or ["⌥←", "⌥→"].
    let keys: [String]
    let action: String
    var note: String? = nil
    /// Word shown between alternatives ("/" for pairs, "then" for sequences).
    var joiner = "/"
    /// Set when this row is a system shortcut the user can rebind; the real binding is shown instead.
    var system: SystemHotkeys.ID? = nil

    /// Keys and note as they apply on this Mac.
    var resolved: (keys: [String], note: String?) {
        guard let system else { return (keys, note) }
        let r = SystemHotkeys.resolve(system)
        return (r.keys, [note, r.note].compactMap { $0 }.joined(separator: " · ").nilIfEmpty)
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

struct CheatSheet: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let entries: [ShortcutEntry]
}

private func e(_ keys: String..., action: String, note: String? = nil, joiner: String = "/",
               system: SystemHotkeys.ID? = nil) -> ShortcutEntry {
    ShortcutEntry(keys: keys, action: action, note: note, joiner: joiner, system: system)
}

enum CheatSheets {
    static func style(_ id: String) -> (symbol: String, color: Color) {
        switch id {
        case "essentials": ("star.fill", .pink)
        case "apps": ("macwindow.on.rectangle", .blue)
        case "text": ("text.cursor", .indigo)
        case "finder": ("folder.fill", .cyan)
        case "screenshots": ("camera.viewfinder", .purple)
        case "browsers": ("safari.fill", .orange)
        case "system": ("gearshape.fill", .gray)
        case "dialogs": ("rectangle.on.rectangle", .green)
        case "terminal": ("terminal.fill", Color(white: 0.3))
        default: ("keyboard", .gray)
        }
    }

    static let all: [CheatSheet] = [
        CheatSheet(id: "essentials", title: "Everyday essentials", symbol: "star", entries: [
            e("⌘C", action: "Copy"),
            e("⌘X", action: "Cut"),
            e("⌘V", action: "Paste"),
            e("⌥⇧⌘V", action: "Paste and match style (no formatting)"),
            e("⌘Z", action: "Undo"),
            e("⇧⌘Z", action: "Redo", note: "Not ⌘Y"),
            e("⌘A", action: "Select all"),
            e("⌘F", action: "Find"),
            e("⌘G", "⇧⌘G", action: "Find next / previous"),
            e("⌘S", action: "Save"),
            e("⇧⌘S", action: "Save As / Duplicate"),
            e("⌘P", action: "Print"),
            e("⌘N", action: "New window or document"),
            e("⌘O", action: "Open"),
            e("⌘W", action: "Close window or tab", note: "The app keeps running"),
            e("⌥⌘W", action: "Close all windows of the app"),
            e("⌘Q", action: "Quit the app"),
            e("⌘,", action: "Open the app's Settings"),
            e("⇧⌘/", action: "Help → search every menu command", note: "Type a command name, arrow to it, press ↩"),
        ]),
        CheatSheet(id: "apps", title: "Apps & windows", symbol: "macwindow.on.rectangle", entries: [
            e("⌘⇥", action: "Switch apps", note: "Hold ⌘, tap ⇥; ⇧ goes back; Q / H quit / hide the highlighted app"),
            e("⌘`", action: "Cycle windows of the current app"),
            e("⌘H", action: "Hide the current app"),
            e("⌥⌘H", action: "Hide every other app"),
            e("⌘M", action: "Minimize window"),
            e("⌃⌘F", action: "Toggle full screen"),
            e("fn⌃F", action: "Fill the screen (window tiling, macOS 15+)"),
            e("fn⌃←", "fn⌃→", action: "Tile window to left / right half"),
            e("fn⌃↑", "fn⌃↓", action: "Tile window to top / bottom half"),
            e("fn⌃C", action: "Center window"),
            e("fn⌃R", action: "Return window to previous size"),
            e("⌃↑", action: "Mission Control (all windows)", system: .missionControl),
            e("⌃↓", action: "App Exposé (this app's windows)", system: .appWindows),
            e("⌃←", "⌃→", action: "Previous / next desktop (Space)"),
            e("F11", action: "Show desktop", note: "fn F11 on laptop keyboards", system: .showDesktop),
            e("⌥⌘⎋", action: "Force Quit an app"),
            e("⌥⌘D", action: "Show / hide the Dock"),
        ]),
        CheatSheet(id: "text", title: "Text editing (works almost everywhere)", symbol: "text.cursor", entries: [
            e("⌥←", "⌥→", action: "Move one word left / right"),
            e("⌘←", "⌘→", action: "Start / end of line", note: "Instead of Home / End"),
            e("⌘↑", "⌘↓", action: "Top / bottom of document"),
            e("⌥↑", "⌥↓", action: "Start / end of paragraph (most editors)"),
            e("⇧", action: "Add ⇧ to any of the above to select", note: "e.g. ⇧⌥→ selects a word"),
            e("⌥⌫", action: "Delete previous word"),
            e("⌘⌫", action: "Delete to start of line"),
            e("fn⌫", action: "Forward delete"),
            e("⌃K", action: "Delete to end of line"),
            e("⌃A", "⌃E", action: "Start / end of line (Emacs-style)"),
            e("⌃T", action: "Swap the two characters around the cursor"),
            e("⌘B", "⌘I", "⌘U", action: "Bold / italic / underline"),
            e("⌘K", action: "Add a link (most apps)"),
            e("⌃⌘Space", action: "Emoji & symbols", note: "Or press 🌐E"),
            e("⌃⌘D", action: "Look up the word under the cursor"),
            e("⌥-", "⌥⇧-", action: "En dash – / em dash —"),
            e("⌥;", action: "Ellipsis …"),
            e("⌥8", action: "Bullet •"),
        ]),
        CheatSheet(id: "finder", title: "Finder", symbol: "folder", entries: [
            e("Space", action: "Quick Look the selection", note: "⌥Space for full screen"),
            e("↩", action: "Rename"),
            e("⌘↓", "⌘O", action: "Open the selection"),
            e("⌘↑", action: "Go to the enclosing folder"),
            e("⌘[", "⌘]", action: "Back / forward"),
            e("⇧⌘N", action: "New folder"),
            e("⌃⌘N", action: "New folder with the selected items"),
            e("⌘D", action: "Duplicate"),
            e("⌘I", action: "Get Info"),
            e("⌘⌫", action: "Move to Trash"),
            e("⌥⌘⌫", action: "Delete immediately (skips Trash)"),
            e("⇧⌘⌫", action: "Empty Trash"),
            e("⌘C", "⌥⌘V", action: "Copy, then move (cut & paste files)", joiner: "then"),
            e("⌥⌘C", action: "Copy the selection's path"),
            e("⇧⌘G", action: "Go to Folder… (type a path, ⇥ completes)"),
            e("⇧⌘H", action: "Home folder"),
            e("⇧⌘D", action: "Desktop"),
            e("⌥⌘L", action: "Downloads"),
            e("⇧⌘O", action: "Documents"),
            e("⇧⌘A", action: "Applications"),
            e("⇧⌘.", action: "Show / hide hidden files"),
            e("⌘1", "⌘2", "⌘3", "⌘4", action: "Icon / list / column / gallery view"),
            e("⌥⌘P", action: "Show path bar"),
            e("⌘T", action: "New tab"),
            e("⌥⌘Space", action: "Finder search window", system: .finderSearch),
        ]),
        CheatSheet(id: "screenshots", title: "Screenshots & recording", symbol: "camera.viewfinder", entries: [
            e("⇧⌘3", action: "Capture the whole screen"),
            e("⇧⌘4", action: "Capture a selection", note: "Hold Space to move the selection, ⌥ to resize from center"),
            e("⇧⌘4", "Space", action: "Capture a window", note: "Then click the window; hold ⌥ to drop the shadow", joiner: "then"),
            e("⇧⌘5", action: "Screenshot toolbar & screen recording", note: "Options: save location, timer"),
            e("⌃⇧⌘4", action: "Capture to the clipboard instead of a file", note: "Add ⌃ to any screenshot shortcut"),
        ]),
        CheatSheet(id: "browsers", title: "Browsers (Safari, Chrome, Brave…)", symbol: "safari", entries: [
            e("⌘L", action: "Jump to the address bar"),
            e("⌘T", action: "New tab"),
            e("⇧⌘T", action: "Reopen the last closed tab"),
            e("⌘W", action: "Close tab"),
            e("⌘1…8", action: "Go to tab 1–8"),
            e("⌘9", action: "Go to the last tab"),
            e("⌃⇥", "⌃⇧⇥", action: "Next / previous tab", note: "⇧⌘] / ⇧⌘[ also work"),
            e("⌘[", "⌘]", action: "Back / forward"),
            e("⌘R", action: "Reload"),
            e("⌘D", action: "Bookmark the page"),
            e("⇧⌘N", action: "New private / incognito window"),
            e("⌘+", "⌘-", "⌘0", action: "Zoom in / out / reset"),
            e("Space", "⇧Space", action: "Page down / up"),
            e("⌥⌘I", action: "Developer tools / Web Inspector"),
            e("⌘Y", action: "History"),
        ]),
        CheatSheet(id: "system", title: "System & Spotlight", symbol: "gearshape", entries: [
            e("⌘Space", action: "Spotlight: launch apps, find files, calculate, convert", system: .spotlight),
            e("⌘↩", action: "In Spotlight: reveal the result in Finder"),
            e("⌃⌘Q", action: "Lock the screen"),
            e("⇧⌘Q", action: "Log out"),
            e("⌃F2", action: "Focus the menu bar (then type to pick a menu)", note: "fn⌃F2 on laptops"),
            e("🌐C", action: "Control Center"),
            e("🌐N", action: "Notification Center"),
            e("🌐Q", action: "Quick Note"),
            e("🌐E", action: "Emoji & symbols"),
            e("⌥⇧", action: "+ volume / brightness key: adjust in finer steps"),
            e("⌥", action: "+ volume / brightness key: open the matching settings"),
        ]),
        CheatSheet(id: "dialogs", title: "Dialogs & sheets", symbol: "rectangle.on.rectangle", entries: [
            e("↩", action: "Press the default (blue) button"),
            e("⎋", "⌘.", action: "Cancel"),
            e("⇧⌘G", action: "Type a path in Open / Save dialogs"),
            e("⇧⌘.", action: "Show hidden files in Open / Save dialogs"),
            e("⌘↑", action: "Enclosing folder in Open / Save dialogs"),
            e("⇥", action: "Move between controls", note: "Turn on System Settings → Keyboard → Keyboard navigation"),
        ]),
        CheatSheet(id: "terminal", title: "Terminal & shell", symbol: "terminal", entries: [
            e("⌃A", "⌃E", action: "Start / end of the command line"),
            e("⌃U", action: "Delete to start of line"),
            e("⌃K", action: "Delete to end of line"),
            e("⌃W", action: "Delete the previous word"),
            e("⌃R", action: "Search command history"),
            e("⌃L", action: "Clear the screen"),
            e("⌘K", action: "Clear scrollback (Terminal, iTerm2)"),
            e("⌃C", action: "Interrupt the running command"),
            e("open .", action: "Open the current folder in Finder"),
            e("pbcopy", "pbpaste", action: "Pipe to / from the clipboard", note: "e.g. cat file | pbcopy"),
        ]),
    ]
}

/// Windows → Mac translation table.
struct WindowsMapping: Identifiable {
    let id = UUID()
    let windows: String
    let mac: [String]
    let what: String
    var note: String? = nil
    var joiner = "/"
    var system: SystemHotkeys.ID? = nil

    var resolved: (keys: [String], note: String?) {
        guard let system else { return (mac, note) }
        let r = SystemHotkeys.resolve(system)
        return (r.keys, [note, r.note].compactMap { $0 }.joined(separator: " · ").nilIfEmpty)
    }
}

enum WindowsMap {
    static let conceptColors: [Color] = [.blue, .purple, .red, .indigo, .teal, .orange]

    static let concepts: [(symbol: String, title: String, body: String)] = [
        ("command", "⌘ is your new Ctrl", "Copy, paste, save, find, new tab… everything you did with Ctrl uses ⌘ Command. Ctrl (⌃) is mostly for terminals, Emacs-style text keys and Spaces."),
        ("option", "⌥ Option ≈ Alt", "Used for variants (hold ⌥ while a menu is open to reveal hidden items), special characters, and word-by-word movement."),
        ("xmark", "Closing ≠ quitting", "The red button or ⌘W closes a window but the app keeps running (dot under its Dock icon). ⌘Q quits."),
        ("menubar.rectangle", "One menu bar, at the top", "The menu bar always belongs to the frontmost app. Every command and its shortcut lives there — ⇧⌘/ searches it."),
        ("globe", "fn / 🌐 Globe", "On Mac keyboards fn turns ↑↓ into Page Up / Down and ⌫ into forward delete; 🌐 + letter opens system features."),
        ("cursorarrow.click", "Right-click", "⌃-click, two-finger click on a trackpad, or the right mouse button."),
    ]

    static let all: [WindowsMapping] = [
        WindowsMapping(windows: "Ctrl+C / X / V", mac: ["⌘C", "⌘X", "⌘V"], what: "Copy / cut / paste"),
        WindowsMapping(windows: "Ctrl+Z", mac: ["⌘Z"], what: "Undo"),
        WindowsMapping(windows: "Ctrl+Y", mac: ["⇧⌘Z"], what: "Redo"),
        WindowsMapping(windows: "Ctrl+A / F / S / P", mac: ["⌘A", "⌘F", "⌘S", "⌘P"], what: "Select all / find / save / print"),
        WindowsMapping(windows: "Ctrl+H", mac: ["⌥⌘F"], what: "Find & replace", note: "In most Mac editors"),
        WindowsMapping(windows: "Alt+Tab", mac: ["⌘⇥"], what: "Switch apps", note: "⌘` switches windows of the same app"),
        WindowsMapping(windows: "Alt+F4", mac: ["⌘Q"], what: "Quit app", note: "⌘W closes just the window"),
        WindowsMapping(windows: "Ctrl+Shift+Esc", mac: ["⌥⌘⎋"], what: "Force Quit / Task Manager", note: "Activity Monitor is the full Task Manager"),
        WindowsMapping(windows: "Win (Start) / Win+S", mac: ["⌘Space"], what: "Search & launch apps (Spotlight)", system: .spotlight),
        WindowsMapping(windows: "Win+D", mac: ["F11"], what: "Show desktop", note: "fn F11 on laptop keyboards", system: .showDesktop),
        WindowsMapping(windows: "Win+Tab", mac: ["⌃↑"], what: "Task view → Mission Control", system: .missionControl),
        WindowsMapping(windows: "Win+← / →", mac: ["fn⌃←", "fn⌃→"], what: "Snap window left / right", note: "macOS 15+"),
        WindowsMapping(windows: "Win+↑", mac: ["fn⌃F", "⌃⌘F"], what: "Maximize / full screen"),
        WindowsMapping(windows: "Win+↓", mac: ["⌘M"], what: "Minimize", note: "Or ⌘H to hide the app"),
        WindowsMapping(windows: "Win+L", mac: ["⌃⌘Q"], what: "Lock screen"),
        WindowsMapping(windows: "Win+E", mac: ["⌥⌘Space"], what: "Open a Finder window", system: .finderSearch),
        WindowsMapping(windows: "Win+.", mac: ["⌃⌘Space"], what: "Emoji picker"),
        WindowsMapping(windows: "Win+V", mac: ["⌘Space"], what: "Clipboard history", note: "Spotlight's clipboard on macOS 26+, or Raycast's Clipboard History"),
        WindowsMapping(windows: "Win+Shift+S", mac: ["⇧⌘4", "⇧⌘5"], what: "Screenshot a region", note: "Add ⌃ to copy instead of saving"),
        WindowsMapping(windows: "PrtScn", mac: ["⇧⌘3"], what: "Screenshot the whole screen"),
        WindowsMapping(windows: "Home / End", mac: ["⌘←", "⌘→"], what: "Start / end of line"),
        WindowsMapping(windows: "Ctrl+Home / End", mac: ["⌘↑", "⌘↓"], what: "Top / bottom of document"),
        WindowsMapping(windows: "Ctrl+← / →", mac: ["⌥←", "⌥→"], what: "Jump by word"),
        WindowsMapping(windows: "Ctrl+Backspace", mac: ["⌥⌫"], what: "Delete previous word"),
        WindowsMapping(windows: "Delete (forward)", mac: ["fn⌫"], what: "Forward delete"),
        WindowsMapping(windows: "F2", mac: ["↩"], what: "Rename (Finder)"),
        WindowsMapping(windows: "Enter (open file)", mac: ["⌘↓", "⌘O"], what: "Open (Finder)"),
        WindowsMapping(windows: "Delete (file)", mac: ["⌘⌫"], what: "Move to Trash"),
        WindowsMapping(windows: "Shift+Delete", mac: ["⌥⌘⌫"], what: "Delete immediately"),
        WindowsMapping(windows: "Backspace (Explorer)", mac: ["⌘↑"], what: "Up one folder"),
        WindowsMapping(windows: "Alt+← / →", mac: ["⌘[", "⌘]"], what: "Back / forward"),
        WindowsMapping(windows: "Ctrl+X → Ctrl+V (files)", mac: ["⌘C", "⌥⌘V"], what: "Move files", joiner: "then"),
        WindowsMapping(windows: "Alt+Enter", mac: ["⌘I"], what: "Properties → Get Info"),
        WindowsMapping(windows: "Ctrl+L / Alt+D / F6", mac: ["⌘L"], what: "Address bar"),
        WindowsMapping(windows: "F5", mac: ["⌘R"], what: "Reload"),
        WindowsMapping(windows: "Ctrl+Shift+T", mac: ["⇧⌘T"], what: "Reopen closed tab"),
        WindowsMapping(windows: "Ctrl+Tab", mac: ["⌃⇥"], what: "Next tab", note: "Same as Windows!"),
        WindowsMapping(windows: "Ctrl+click", mac: ["⌘Click"], what: "Add to selection"),
        WindowsMapping(windows: "Win+I", mac: ["⌘,"], what: "Settings (of the current app)"),
    ]
}
