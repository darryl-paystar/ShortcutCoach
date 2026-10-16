import SwiftUI

// MARK: - App Shortcuts (live menus of any running app)

struct CurrentAppView: View {
    @ObservedObject private var tracker = FrontmostTracker.shared
    @State private var pid: pid_t?
    @State private var items: [MenuShortcut] = []
    @State private var loading = false
    @State private var query = ""
    @State private var includeUnbound = false

    private var apps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            // Regular (Dock) apps, plus the selected one even if it's a menu-bar app like Shottr.
            .filter { ($0.activationPolicy == .regular || $0.processIdentifier == pid) && $0.processIdentifier != Apps.ownPID }
            .sorted { ($0.localizedName ?? "") .localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending }
    }

    private var sections: [(menu: String, items: [MenuShortcut])] {
        let q = query.lowercased()
        var order: [String] = []
        var grouped: [String: [MenuShortcut]] = [:]
        for item in items {
            guard includeUnbound || item.combo != nil else { continue }
            if !q.isEmpty {
                let hay = (item.path.joined(separator: " ") + " " + (item.combo?.display ?? "")).lowercased()
                guard hay.contains(q) else { continue }
            }
            if grouped[item.menu] == nil { order.append(item.menu) }
            grouped[item.menu, default: []].append(item)
        }
        return order.map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let app = apps.first(where: { $0.processIdentifier == pid }) {
                    HintIcon(bundleID: app.bundleIdentifier, symbol: "app", size: 28)
                }
                // A Menu rather than a Picker: macOS 27 draws a blank Picker when nothing matches a tag.
                Menu {
                    ForEach(apps, id: \.processIdentifier) { app in
                        Button(app.localizedName ?? "App") { pid = app.processIdentifier }
                    }
                } label: {
                    Text(apps.first { $0.processIdentifier == pid }?.localizedName ?? "Choose an App")
                }
                .fixedSize()
                Toggle("Include items without a shortcut", isOn: $includeUnbound)
                Spacer()
                if loading { ProgressView().controlSize(.small) }
                Text("\(items.filter { $0.combo != nil }.count) shortcuts").font(.caption).foregroundStyle(.secondary)
                Button { load(force: true) } label: { Image(systemName: "arrow.clockwise") }
                    .help("Re-read the app's menus")
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .frame(maxWidth: 820 + 48)
            .frame(maxWidth: .infinity)

            // Grouped boxes on the content ground, like Cheat Sheets; content fades out under the app picker row.
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ForEach(sections, id: \.menu) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(section.menu)
                            GroupedBox {
                                ForEach(section.items) { item in
                                    MenuItemRow(item: item, appName: apps.first { $0.processIdentifier == pid }?.localizedName ?? "the app")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: 820 + 48, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .modifier(ToolbarFade())
            .overlay {
                if !loading && sections.isEmpty {
                    Text(items.isEmpty ? "No menus found for this app." : "No matches.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .background(Color.contentGround)
        .searchable(text: $query, prompt: "Search commands or keys")
        .onAppear {
            if pid == nil {
                let last = tracker.lastExternalApp
                pid = last?.activationPolicy == .regular ? last?.processIdentifier : apps.first?.processIdentifier
            }
            load(force: false)
        }
        .onChange(of: pid) { load(force: false) }
    }

    private func load(force: Bool) {
        guard let pid else { return }
        loading = true
        MenuIndex.shared.entry(pid: pid, maxAge: force ? 0 : 30) { entry in
            DispatchQueue.main.async {
                guard pid == self.pid else { return }
                items = entry.items
                loading = false
            }
        }
    }
}

private struct MenuItemRow: View {
    let item: MenuShortcut
    let appName: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.system(size: 13))
                if item.path.count > 2 {
                    Text(item.path.dropFirst().dropLast().joined(separator: " ▸ "))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            if let combo = item.combo {
                KeycapRow(groups: [combo.keycaps], size: 12)
            } else {
                Text("no shortcut").font(.system(size: 11.5)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy Menu Title") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.title, forType: .string)
            }
            Button("Assign a Shortcut in System Settings…") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.title, forType: .string)
                if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .help(item.combo == nil
              ? "Right-click to add your own shortcut: Keyboard → Keyboard Shortcuts… → App Shortcuts → +, choose \(appName), paste the title."
              : item.path.joined(separator: " → "))
    }
}

// MARK: - Cheat sheets

struct CheatSheetsView: View {
    @State private var query = ""
    @State private var selected = "all"

    static func shortTitle(_ sheet: CheatSheet) -> String {
        sheet.title.components(separatedBy: " (").first ?? sheet.title
    }

    private var sheets: [CheatSheet] {
        let q = query.lowercased()
        return CheatSheets.all.compactMap { sheet in
            if selected != "all", sheet.id != selected { return nil }
            guard !q.isEmpty else { return sheet }
            let entries = sheet.entries.filter {
                ($0.action + " " + ($0.note ?? "") + " " + $0.keys.joined(separator: " ")).lowercased().contains(q)
            }
            return entries.isEmpty ? nil : CheatSheet(id: sheet.id, title: sheet.title, symbol: sheet.symbol, entries: entries)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(sheets) { sheet in
                    VStack(alignment: .leading, spacing: 8) {
                        let style = CheatSheets.style(sheet.id)
                        HStack(spacing: 9) {
                            IconTile(symbol: style.symbol, color: style.color, size: 22)
                            Text(sheet.title).font(.system(size: 13, weight: .semibold))
                        }
                        GroupedBox {
                            ForEach(sheet.entries) { entry in
                                ShortcutRow(action: entry.action, resolved: entry.resolved, joiner: entry.joiner)
                            }
                        }
                    }
                }
                if sheets.isEmpty {
                    Card(wash: true) {
                        Text("No shortcuts match “\(query)”.").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .sectionGround()
        .searchable(text: $query, prompt: "Search shortcuts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("All Categories") { selected = "all" }
                    Divider()
                    ForEach(CheatSheets.all) { sheet in
                        Button(Self.shortTitle(sheet)) { selected = sheet.id }
                    }
                } label: {
                    Label(selected == "all" ? "All Categories" : CheatSheets.all.first { $0.id == selected }.map(Self.shortTitle) ?? "All",
                          systemImage: "line.3.horizontal.decrease")
                        .labelStyle(.titleAndIcon)
                }
                .fixedSize()
            }
        }
    }
}

private struct ShortcutRow: View {
    let action: String
    let resolved: (keys: [String], note: String?)
    let joiner: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(action).font(.system(size: 13))
                if let note = resolved.note {
                    Text(note).font(.system(size: 11.5)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            KeycapRow(shortcuts: resolved.keys, size: 12, joiner: joiner)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct TitleWithSecondaryIcon: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 7) {
            configuration.icon.foregroundStyle(.secondary).font(.system(size: 12))
            configuration.title
        }
    }
}

// MARK: - Coming from Windows

struct WindowsView: View {
    @State private var query = ""

    private var rows: [WindowsMapping] {
        let q = query.lowercased()
        guard !q.isEmpty else { return WindowsMap.all }
        return WindowsMap.all.filter { ($0.windows + " " + $0.what + " " + ($0.note ?? "")).lowercased().contains(q) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if query.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("The big differences")
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(Array(WindowsMap.concepts.enumerated()), id: \.element.title) { i, c in
                                Card {
                                    HStack(alignment: .top, spacing: 12) {
                                        IconTile(symbol: c.symbol, color: WindowsMap.conceptColors[i % WindowsMap.conceptColors.count], size: 28)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(c.title).font(.system(size: 13, weight: .semibold))
                                            Text(c.body).font(.system(size: 12)).foregroundStyle(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                    .frame(maxHeight: .infinity, alignment: .top)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("Shortcut translations")
                    GroupedBox {
                        HStack(spacing: 16) {
                            Text("Windows").frame(width: 190, alignment: .leading)
                            Text("Mac").frame(width: 190, alignment: .leading)
                            Text("Does")
                            Spacer()
                        }
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)

                        ForEach(rows) { m in
                            let r = m.resolved
                            HStack(alignment: .center, spacing: 16) {
                                WindowsKeys(text: m.windows)
                                    .frame(width: 190, alignment: .leading)
                                KeycapRow(shortcuts: r.keys, size: 12, joiner: m.joiner)
                                    .frame(width: 190, alignment: .leading)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(m.what).font(.system(size: 13))
                                    if let note = r.note {
                                        Text(note).font(.system(size: 11.5)).foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 880, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .sectionGround()
        .searchable(text: $query, prompt: "Search, e.g. Alt+Tab")
    }
}

/// Windows-side shortcut, shown as flat square chips so it reads differently from the Mac keycaps.
private struct WindowsKeys: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.blue.opacity(0.9))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.blue.opacity(0.1)))
    }
}

// MARK: - Tips

enum TipStyle {
    static func color(_ category: String) -> Color {
        switch category {
        case "Menus": .indigo
        case "Apps": .blue
        case "Windows": .teal
        case "Finder": .cyan
        case "Text": .purple
        case "Screenshots": .pink
        case "Spotlight": .gray
        case "System": Color(white: 0.45)
        case "Dock", "Browsers": .orange
        case "Terminal": Color(white: 0.3)
        default: .green
        }
    }

    static func symbol(_ category: String) -> String {
        switch category {
        case "Menus": "menubar.rectangle"
        case "Apps": "square.stack.3d.up.fill"
        case "Windows": "macwindow"
        case "Finder": "folder.fill"
        case "Text": "text.cursor"
        case "Screenshots": "camera.viewfinder"
        case "Spotlight": "magnifyingglass"
        case "System": "gearshape.fill"
        case "Dock": "dock.rectangle"
        case "Browsers": "safari.fill"
        case "Terminal": "terminal.fill"
        default: "sparkles"
        }
    }
}

struct TipsView: View {
    @State private var query = ""
    @State private var category = "all"

    private var categories: [String] {
        var seen = Set<String>()
        return Tips.all.map(\.category).filter { seen.insert($0).inserted }
    }

    private var tips: [Tip] {
        let q = query.lowercased()
        return Tips.all.filter { tip in
            (category == "all" || tip.category == category)
                && (q.isEmpty || (tip.title + " " + tip.body).lowercased().contains(q))
        }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
                ForEach(tips) { tip in
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 7) {
                                IconTile(symbol: TipStyle.symbol(tip.category), color: TipStyle.color(tip.category), size: 18)
                                Text(tip.category).font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(TipStyle.color(tip.category))
                            }
                            .padding(.bottom, 2)
                            Text(tip.title).font(.system(size: 13, weight: .semibold))
                            Text(tip.body)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            if !tip.shortcuts.isEmpty {
                                KeycapRow(shortcuts: tip.shortcuts, size: 12, joiner: tip.joiner)
                                    .padding(.top, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                    }
                }
            }
            .padding(24)
        }
        .sectionGround()
        .searchable(text: $query, prompt: "Search tips")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button("All Topics") { category = "all" }
                    Divider()
                    ForEach(categories, id: \.self) { c in Button(c) { category = c } }
                } label: {
                    Label(category == "all" ? "All Topics" : category, systemImage: "line.3.horizontal.decrease")
                        .labelStyle(.titleAndIcon)
                }
                .fixedSize()
                Button { TipScheduler.shared.showNext() } label: {
                    Label("Show a Tip", systemImage: "text.bubble")
                }
                .help("Show the next tip as a hint")
            }
        }
    }
}
