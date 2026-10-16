import AppKit
import SwiftUI

/// `ShortcutCoach --selftest [outDir]`: exercises parsing, live menu reading (Finder) and renders
/// the toast / overlay to PNGs without needing the event tap. Exits non-zero on failure.
@MainActor
enum SelfTest {
    static func run(outDir: String?) -> Int32 {
        GlassBackground.plain = true
        var failures = 0
        func check(_ ok: Bool, _ what: String) {
            print(ok ? "  ok   \(what)" : "  FAIL \(what)")
            if !ok { failures += 1 }
        }

        print("Key parsing")
        check(KeyCombo.keycaps(from: "⇧⌘N") == ["⇧", "⌘", "N"], "⇧⌘N → keycaps")
        check(KeyCombo.keycaps(from: "fn⌃F") == ["fn", "⌃", "F"], "fn⌃F → keycaps")
        check(KeyCombo.keycaps(from: "⌃⌘Space") == ["⌃", "⌘", "Space"], "⌃⌘Space → keycaps")
        check(KeyCombo.keycaps(from: "⌘") == ["⌘"], "lone ⌘")
        check(KeyCombo.parse("⌥⌘L").mods == [.option, .command], "⌥⌘L mods")
        check(Mods(axMenuModifiers: 2) == [.option, .command], "AX modifiers 2 = ⌥⌘")
        check(Mods(axMenuModifiers: 12) == [.control], "AX modifiers 12 = ⌃ (no ⌘)")
        check(MenuIndex.combo(char: "", modifiers: 0, glyph: 104)?.display == "⌘↑", "glyph 104 = ⌘↑")
        check(MenuIndex.combo(char: " ", modifiers: 0, glyph: nil)?.key == "Space", "space key name")
        let punct = KeyCombo([.command], "}")
        check(punct.matchKeys.contains(KeyCombo([.shift, .command], "}").matchKeys[1]), "⇧ relaxed for punctuation")
        check(!KeyCombo([.command], "N").matchKeys.contains(KeyCombo([.shift, .command], "N").matchKeys[0]), "⌘N ≠ ⇧⌘N")
        check(MenuIndex.normalize("Go to Folder…") == "go to folder", "normalize ellipsis")

        print("Stats & system shortcuts")
        let legacy = #"{"id":"x","kind":"menu","appName":"Finder","title":"New Folder","keycapGroups":[["⇧","⌘","N"]],"matchKeys":["12|N"],"shown":2,"used":1,"muted":false}"#
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let old = try? dec.decode(HintRecord.self, from: Data(legacy.utf8))
        check(old?.shown == 2 && old?.alreadyKnown == false && old?.mouseStreak == 0, "old stats file still loads")
        var known = old!
        known.alreadyKnown = true
        known.used = 9
        check(known.isKnown && !known.isLearned, "already-known isn't counted as learned")
        for id in SystemHotkeys.ID.allCases {
            let r = SystemHotkeys.resolve(id)
            print("  info \(id): \(r.keys.joined(separator: " / "))\(r.note.map { " — " + $0 } ?? "")")
        }
        if let l = SystemHotkeys.launcher { print("  info launcher: \(l.name) \(l.combo.display)") }

        print("Live menus (Finder)")
        if let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first {
            let sem = DispatchSemaphore(value: 0)
            var entry: MenuIndex.Entry?
            let start = Date()
            MenuIndex.shared.entry(pid: finder.processIdentifier) { entry = $0; sem.signal() }
            sem.wait()
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            let e = entry!
            check(e.items.count > 100, "read \(e.items.count) menu items in \(ms) ms")
            check(e.byTitle["downloads"]?.combo?.display == "⌥⌘L", "Downloads = ⌥⌘L (got \(e.byTitle["downloads"]?.combo?.display ?? "nil"))")
            check(e.byTitle["new folder"]?.combo?.display == "⇧⌘N", "New Folder = ⇧⌘N")
            check(e.byTitle["as list"]?.combo?.display == "⌘2", "as List = ⌘2")
            check(e.byTitle["back"]?.combo?.display == "⌘[", "Back = ⌘[")
            check(e.byTitle["home"] != nil, "Home found")
            let layout = OverlayLayout(items: e.items, limit: CGSize(width: 1400, height: 800))
            check(!layout.columns.isEmpty, "overlay: \(layout.columns.count) columns, \(layout.totalShortcuts) shortcuts, overflow \(layout.overflow)")

            if let outDir {
                render(OverlayView(appName: "Finder", bundleID: "com.apple.finder", layout: layout), to: outDir + "/overlay.png")
            }
        } else {
            print("  skip Finder not running")
        }

        // Toast.show offers mute only when the model has a hint ID, so the preview needs one to look like a real hint.
        check(ToastModel.sample.hintID != nil, "hint preview shows mute")

        if let outDir {
            render(ToastView(model: .sample, onClose: {}, onMute: {}), to: outDir + "/toast-hint.png")
            let habit = Hint(id: "habit|ctrl-C", kind: .habit, bundleID: nil, appName: "Windows habit", title: "Copy",
                             combos: [KeyCombo([.command], "C")], eyebrow: "Windows habit · Ctrl+C",
                             message: "On a Mac, ⌘ Command does most of what Ctrl did on Windows.", symbol: "arrow.left.arrow.right")
            var rec = HintRecord(id: habit.id, kind: .habit, bundleID: nil, appName: habit.appName, title: habit.title,
                                 keycapGroups: habit.keycapGroups, matchKeys: ["8|C"])
            rec.shown = 4
            rec.used = 1
            render(ToastView(model: .hint(habit, record: rec), onClose: {}, onMute: {}), to: outDir + "/toast-habit.png")
            render(ToastView(model: .tip(Tips.all[0]), onClose: {}, onMute: nil), to: outDir + "/toast-tip.png")
            render(ToastView(model: .noShortcut(appName: "Finder", bundleID: "com.apple.finder", title: "Merge All Windows",
                                                path: ["Window", "Merge All Windows"], count: 3), onClose: {}, onMute: nil),
                   to: outDir + "/toast-suggest.png")
            // Unscrolled, because ImageRenderer leaves ScrollView content blank; a preview taller than the window
            // means that step scrolls in the app. Link buttons and switches draw as a yellow placeholder.
            for i in 0..<5 {
                let size = render(OnboardingView(startAt: i, scrolls: false, onFinish: {}), to: outDir + "/onboarding-\(i).png")
                if let h = size?.height, h > OnboardingView.size.height {
                    print("  info onboarding step \(i) is \(Int(h)) pt tall, so it scrolls in the \(Int(OnboardingView.size.height)) pt window")
                }
            }

            // Brand moments. ImageRenderer leaves ScrollView content blank, so these draw the views directly.
            var used = HintRecord(id: "menu|finder|new folder", kind: .menu, bundleID: "com.apple.finder", appName: "Finder",
                                  title: "New Folder", keycapGroups: [["⇧", "⌘", "N"]], matchKeys: ["12|N"])
            used.used = 1
            render(ToastView(model: .celebration(used), onClose: {}, onMute: nil), to: outDir + "/toast-celebrate.png")
            used.used = HintRecord.learnedThreshold
            let learned = ToastModel.celebration(used)
            check(learned.style == .learned && learned.tint == nil, "5th use → learned toast, untinted")
            for dark in [false, true] {
                let suffix = dark ? "-dark" : ""
                render(ToastView(model: learned, onClose: {}, onMute: nil), to: outDir + "/toast-learned\(suffix).png", dark: dark)
                render(WelcomeStep().frame(width: OnboardingView.size.width - 80).padding(.horizontal, 40).padding(.vertical, 24),
                       to: outDir + "/welcome\(suffix).png", dark: dark)
                render(VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("Still learning", detail: "Sorted by how often you reached for the mouse.")
                    OverviewEmptyState(title: "Nothing left to learn right now.")
                    Card(wash: true) { Text("No shortcuts match “zz”.").foregroundStyle(.secondary) }
                    GroupedBox {
                        HStack {
                            Text("New Folder").font(.system(size: 13))
                            Spacer()
                            KeycapRow(groups: [["⇧", "⌘", "N"]], size: 12)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                }
                .padding(24)
                .frame(width: 640)
                .background(Color.contentGround), to: outDir + "/ground\(suffix).png", dark: dark)
            }
            print("Rendered previews to \(outDir)")
        }

        print(failures == 0 ? "All checks passed" : "\(failures) check(s) failed")
        return failures == 0 ? 0 : 1
    }

    /// Returns the rendered size in points, or nil if rendering failed.
    @discardableResult
    private static func render<V: View>(_ view: V, to path: String, dark: Bool = false) -> CGSize? {
        let content = view.background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, dark ? .dark : .light)
        var png: Data?
        var size: CGSize?
        // Dynamic NSColors (system colors, brandWash) resolve against the current drawing appearance.
        NSAppearance(named: dark ? .darkAqua : .aqua)!.performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            if let image = renderer.nsImage, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                png = rep.representation(using: .png, properties: [:])
                size = image.size
            }
        }
        guard let png else {
            print("  FAIL render \(path)")
            return nil
        }
        try? png.write(to: URL(fileURLWithPath: path))
        return size
    }
}
