import AppKit

struct Tip: Identifiable {
    var id: String { title }
    let category: String
    let title: String
    let body: String
    var shortcuts: [String] = []
    var joiner = "/"
}

enum Tips {
    static let all: [Tip] = [
        Tip(category: "Menus", title: "Search every menu",
            body: "⇧⌘/ opens the Help menu's search. Type part of any command name and macOS points at the menu item — and shows its shortcut.",
            shortcuts: ["⇧⌘/"]),
        Tip(category: "Menus", title: "Hold ⌥ for hidden menu items",
            body: "With a menu open, hold ⌥ and some items change: Close → Close All, Minimize → Minimize All, and Finder's Go menu reveals Library.",
            shortcuts: ["⌥"]),
        Tip(category: "Menus", title: "Make your own shortcuts",
            body: "System Settings → Keyboard → Keyboard Shortcuts… → App Shortcuts → +. Pick an app, type a menu item's exact title, press your keys. Works for any app."),
        Tip(category: "Apps", title: "⌘⇥ has hidden powers",
            body: "While the app switcher is open: press Q to quit the highlighted app, H to hide it, or ↓ to see its windows.",
            shortcuts: ["⌘⇥"]),
        Tip(category: "Apps", title: "Switch windows, not apps",
            body: "⌘⇥ switches apps; ⌘` cycles between windows of the same app (⇧⌘` goes backwards).",
            shortcuts: ["⌘`"]),
        Tip(category: "Apps", title: "Hide instead of minimize",
            body: "⌘H hides the whole app in one go and ⌘⇥ brings it straight back. ⌥⌘H hides everything except the current app.",
            shortcuts: ["⌘H", "⌥⌘H"]),
        Tip(category: "Apps", title: "Quit means ⌘Q",
            body: "Closing a window (⌘W or the red button) usually leaves the app running — look for the dot under its Dock icon. ⌘Q actually quits.",
            shortcuts: ["⌘Q"]),
        Tip(category: "Windows", title: "Tile windows from the keyboard",
            body: "fn⌃← / fn⌃→ snap the window to a half, fn⌃F fills the screen, fn⌃R puts it back. Or drag a window to a screen edge while holding ⌥.",
            shortcuts: ["fn⌃←", "fn⌃F"]),
        Tip(category: "Windows", title: "Move a window without focusing it",
            body: "Hold ⌘ and drag a background window's title bar — it moves without coming to the front.",
            shortcuts: ["⌘"]),
        Tip(category: "Windows", title: "⌥-click the green button",
            body: "Clicking the green button enters full screen. ⌥-click zooms (maximizes) instead, and hovering shows tiling options.",
            shortcuts: []),
        Tip(category: "Windows", title: "See where a document lives",
            body: "⌘-click the title of a document window to get a menu of its folder path — pick any folder to open it in Finder.",
            shortcuts: []),
        Tip(category: "Finder", title: "Quick Look anything",
            body: "Select a file and press Space to preview it — PDFs, images, video, code. ⌥Space opens it full screen. Works in Open dialogs too.",
            shortcuts: ["Space"]),
        Tip(category: "Finder", title: "Type a path anywhere",
            body: "⇧⌘G opens “Go to Folder” in Finder and in every Open / Save dialog. Type ~/Projects and use ⇥ to autocomplete.",
            shortcuts: ["⇧⌘G"]),
        Tip(category: "Finder", title: "Drag a folder into a dialog",
            body: "In an Open or Save dialog, drag a file or folder from Finder onto the dialog to jump straight to that location.",
            shortcuts: []),
        Tip(category: "Finder", title: "Cut & paste files",
            body: "There's no ⌘X for files. Copy with ⌘C, then paste with ⌥⌘V to move them instead of copying.",
            shortcuts: ["⌘C", "⌥⌘V"], joiner: "then"),
        Tip(category: "Finder", title: "Copy a file's path",
            body: "Select a file in Finder and press ⌥⌘C to copy its full path — handy for terminals and config files.",
            shortcuts: ["⌥⌘C"]),
        Tip(category: "Finder", title: "Show hidden files",
            body: "⇧⌘. toggles dotfiles and hidden folders in Finder and in Open / Save dialogs.",
            shortcuts: ["⇧⌘."]),
        Tip(category: "Finder", title: "Rename a batch of files",
            body: "Select several files, right-click → Rename… for find & replace, adding text, or numbering them in sequence.",
            shortcuts: []),
        Tip(category: "Finder", title: "Jump to common folders",
            body: "⇧⌘H Home, ⇧⌘D Desktop, ⌥⌘L Downloads, ⇧⌘O Documents, ⇧⌘A Applications — from any Finder window.",
            shortcuts: ["⌥⌘L", "⇧⌘H"]),
        Tip(category: "Text", title: "Move by word and line",
            body: "⌥← / ⌥→ jump by word, ⌘← / ⌘→ to the start / end of the line, ⌘↑ / ⌘↓ to the top / bottom. Add ⇧ to select.",
            shortcuts: ["⌥←", "⌘←"]),
        Tip(category: "Text", title: "Delete faster",
            body: "⌥⌫ deletes the previous word, ⌘⌫ deletes to the start of the line, fn⌫ deletes forward.",
            shortcuts: ["⌥⌫", "⌘⌫"]),
        Tip(category: "Text", title: "Emacs keys are everywhere",
            body: "In nearly every Mac text field: ⌃A / ⌃E go to line start / end, ⌃K cuts to end of line, ⌃Y pastes it back, ⌃T swaps two letters.",
            shortcuts: ["⌃A", "⌃E", "⌃K"]),
        Tip(category: "Text", title: "Accents without a menu",
            body: "Press and hold a letter key (like e) to get a popup of accented versions — then press the number shown.",
            shortcuts: []),
        Tip(category: "Text", title: "Paste without formatting",
            body: "⌥⇧⌘V pastes plain text that matches the surrounding style — no more stray fonts from web pages.",
            shortcuts: ["⌥⇧⌘V"]),
        Tip(category: "Text", title: "Text replacements",
            body: "System Settings → Keyboard → Text Replacements… lets you expand short codes (like “@@”) into email addresses, phrases, or snippets everywhere.",
            shortcuts: []),
        Tip(category: "Text", title: "Look up any word",
            body: "⌃⌘D (or a force click / three-finger tap) shows the dictionary definition for the word under the cursor.",
            shortcuts: ["⌃⌘D"]),
        Tip(category: "Screenshots", title: "Screenshot a single window",
            body: "⇧⌘4, then press Space and click a window. Hold ⌥ while clicking to leave out the shadow.",
            shortcuts: ["⇧⌘4", "Space"], joiner: "then"),
        Tip(category: "Screenshots", title: "Screenshots to the clipboard",
            body: "Add ⌃ to any screenshot shortcut (⌃⇧⌘4) to copy it instead of saving a file to the Desktop.",
            shortcuts: ["⌃⇧⌘4"]),
        Tip(category: "Screenshots", title: "Record the screen",
            body: "⇧⌘5 opens the capture toolbar: record the whole screen or a region, set a timer, and change where files are saved.",
            shortcuts: ["⇧⌘5"]),
        Tip(category: "Spotlight", title: "Spotlight is a calculator",
            body: "⌘Space, then type math (15% of 240), unit or currency conversions (5 km in miles, 100 usd in eur) — no app needed.",
            shortcuts: ["⌘Space"]),
        Tip(category: "Spotlight", title: "Reveal instead of open",
            body: "In Spotlight results, ⌘↩ shows the file in Finder instead of opening it.",
            shortcuts: ["⌘↩"]),
        Tip(category: "System", title: "Lock your Mac instantly",
            body: "⌃⌘Q locks the screen — the Mac's Win+L.",
            shortcuts: ["⌃⌘Q"]),
        Tip(category: "System", title: "Force Quit",
            body: "⌥⌘⎋ opens Force Quit — the closest thing to Ctrl+Shift+Esc. Activity Monitor is the full Task Manager.",
            shortcuts: ["⌥⌘⎋"]),
        Tip(category: "System", title: "Finer volume and brightness",
            body: "Hold ⌥⇧ while pressing a volume or brightness key to adjust in quarter steps. ⌥ + the key opens its settings.",
            shortcuts: []),
        Tip(category: "System", title: "Hidden details in the menu bar",
            body: "⌥-click the Wi-Fi, Bluetooth or Sound icons in the menu bar for extra technical details and options.",
            shortcuts: []),
        Tip(category: "System", title: "Rearrange menu bar icons",
            body: "Hold ⌘ and drag icons in the menu bar to reorder them; drag one off the bar to remove it.",
            shortcuts: []),
        Tip(category: "System", title: "Hot Corners",
            body: "System Settings → Desktop & Dock → Hot Corners… Hold a modifier while choosing to require it (so you don't trigger corners by accident).",
            shortcuts: []),
        Tip(category: "System", title: "Keyboard navigation in dialogs",
            body: "Turn on System Settings → Keyboard → Keyboard navigation to ⇥ between every button and control, then press Space to click.",
            shortcuts: ["⇥"]),
        Tip(category: "Dock", title: "Show an app in Finder",
            body: "⌘-click any Dock icon to reveal that app (or the folder) in Finder.",
            shortcuts: []),
        Tip(category: "Dock", title: "Auto-hide the Dock",
            body: "⌥⌘D toggles Dock hiding — instant extra screen space.",
            shortcuts: ["⌥⌘D"]),
        Tip(category: "Browsers", title: "Reopen a closed tab",
            body: "⇧⌘T brings back the last tab you closed — press it again for the one before.",
            shortcuts: ["⇧⌘T"]),
        Tip(category: "Browsers", title: "Jump to a tab by number",
            body: "⌘1 through ⌘8 jump to that tab; ⌘9 always goes to the last one.",
            shortcuts: ["⌘1…8", "⌘9"]),
        Tip(category: "Terminal", title: "Bridge Finder and Terminal",
            body: "Type open . to open the current folder in Finder. Drag any file onto a Terminal window to paste its path.",
            shortcuts: []),
        Tip(category: "Terminal", title: "Clipboard from the shell",
            body: "Pipe into pbcopy to copy output (git diff | pbcopy) and use pbpaste to read the clipboard.",
            shortcuts: []),
        Tip(category: "Shortcut Coach", title: "Hold ⌘ for a cheat sheet",
            body: "Hold ⌘ for a moment in any app to see every shortcut in its menus. Press any key or click to close it.",
            shortcuts: ["⌘"]),
    ]
}

/// Shows a tip toast every so often, while you're actively using the Mac.
final class TipScheduler {
    static let shared = TipScheduler()
    private var timer: Timer?
    private var order: [Int] = []

    func start() {
        order = Array(Tips.all.indices).shuffled(using: &seeded)
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.tick() }
    }

    func showNext() {
        let d = Prefs.d
        let i = d.integer(forKey: Prefs.Key.tipIndex)
        let tip = Tips.all[order.isEmpty ? i % Tips.all.count : order[i % order.count]]
        d.set(i + 1, forKey: Prefs.Key.tipIndex)
        d.set(Date().timeIntervalSince1970, forKey: Prefs.Key.lastTipAt)
        Toast.shared.show(.tip(tip))
    }

    private func tick() {
        guard Prefs.enabled, Prefs.on(Prefs.Key.periodicTips), !Toast.shared.isVisible else { return }
        let last = Prefs.d.double(forKey: Prefs.Key.lastTipAt)
        guard Date().timeIntervalSince1970 - last >= Prefs.tipInterval else { return }
        // Only while the user is active (any input in the last 30 s).
        let idle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: ~0)!)
        guard idle < 30 else { return }
        showNext()
    }

    /// A stable shuffle so the tip order survives relaunches.
    private var seeded = SeededGenerator(seed: 0x5EED)
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
