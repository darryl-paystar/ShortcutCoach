import SwiftUI

enum MainSection: String, CaseIterable, Identifiable, Hashable {
    case overview, currentApp, cheatSheets, windows, tips, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .currentApp: "App Shortcuts"
        case .cheatSheets: "Cheat Sheets"
        case .windows: "Coming from Windows"
        case .tips: "Tips & Tricks"
        case .settings: "Settings"
        }
    }

    var color: Color {
        switch self {
        case .overview: .indigo
        case .currentApp: .blue
        case .cheatSheets: .orange
        case .windows: .teal
        case .tips: .yellow
        case .settings: .gray
        }
    }

    var tileSymbol: String {
        switch self {
        case .overview: "chart.bar.fill"
        case .currentApp: "menubar.rectangle"
        case .cheatSheets: "keyboard.fill"
        case .windows: "arrow.left.arrow.right"
        case .tips: "lightbulb.fill"
        case .settings: "gearshape.fill"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "chart.bar.xaxis"
        case .currentApp: "menubar.rectangle"
        case .cheatSheets: "keyboard"
        case .windows: "arrow.left.arrow.right"
        case .tips: "lightbulb"
        case .settings: "gearshape"
        }
    }
}

struct MainView: View {
    @ObservedObject private var nav = Navigation.shared

    var body: some View {
        // The sidebar always shows: no toggle here, and AppDelegate.pinSidebar() stops the divider collapsing it.
        NavigationSplitView {
            List(selection: Binding<MainSection?>(get: { nav.section }, set: { if let s = $0 { nav.section = s } })) {
                Section {
                    ForEach([MainSection.overview, .currentApp]) { s in
                        Label { Text(s.title) } icon: { IconTile(symbol: s.tileSymbol, color: s.color, size: 20) }.tag(s)
                    }
                }
                Section("Learn") {
                    ForEach([MainSection.cheatSheets, .windows, .tips]) { s in
                        Label { Text(s.title) } icon: { IconTile(symbol: s.tileSymbol, color: s.color, size: 20) }.tag(s)
                    }
                }
                Section {
                    Label { Text(MainSection.settings.title) } icon: {
                        IconTile(symbol: MainSection.settings.tileSymbol, color: MainSection.settings.color, size: 20)
                    }
                    .tag(MainSection.settings)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch nav.section {
                case .overview: OverviewView()
                case .currentApp: CurrentAppView()
                case .cheatSheets: CheatSheetsView()
                case .windows: WindowsView()
                case .tips: TipsView()
                case .settings: SettingsView()
                }
            }
            .navigationTitle(nav.section.title)
        }
        .frame(minWidth: 820, minHeight: 520)
    }
}

// MARK: - Shared bits

extension View {
    /// Ground for a scrolling main-window section: content fades out just before it reaches the toolbar
    /// (the titlebar is transparent, so nothing else keeps it from clashing with the title), over contentGround.
    func sectionGround() -> some View {
        modifier(ToolbarFade()).background(Color.contentGround)
    }
}

/// Masks the area under the toolbar: clear up to the toolbar's bottom edge, then a short fade into full opacity.
struct ToolbarFade: ViewModifier {
    func body(content: Content) -> some View {
        content.mask {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Color.clear.frame(height: max(0, geo.safeAreaInsets.top - 4))
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: 24)
                    Color.black
                }
                .ignoresSafeArea()
            }
        }
    }
}

/// Coaching on/off as one quiet pill in the toolbar instead of a glass toolbar button: a status dot, the status,
/// and the ⇧⌘P keycaps (the app menu's Pause / Resume Coaching item). Clicking it toggles too.
private struct CoachingToolbarItem: ToolbarContent {
    let status: String
    let dot: Color
    @Binding var enabled: Bool

    var body: some ToolbarContent {
        if #available(macOS 26.0, *) {
            ToolbarItem(placement: .primaryAction) { pill }.sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .primaryAction) { pill }
        }
    }

    private var pill: some View {
        CoachingPill(status: status, dot: dot, enabled: $enabled)
    }
}

private struct CoachingPill: View {
    let status: String
    let dot: Color
    @Binding var enabled: Bool
    @State private var hovering = false

    var body: some View {
        let capsule = Capsule(style: .continuous)
        Button {
            enabled.toggle()
            if !enabled { Toast.shared.dismiss() }
        } label: {
            HStack(spacing: 8) {
                Circle().fill(dot).frame(width: 7, height: 7)
                Text(status)
                    .font(.system(size: 13))
                    .foregroundStyle(enabled ? .primary : .secondary)
                KeycapRow(groups: [["⇧", "⌘", "P"]], size: 11)
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .padding(.vertical, 6)
            .background(capsule.fill(Color(nsColor: .controlBackgroundColor)))
            .background(capsule.fill(Color.primary.opacity(hovering ? 0.06 : 0)))
            .overlay(capsule.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
            .contentShape(capsule)
        }
        .buttonStyle(.plain)
        .onHover { inside in withAnimation(.easeOut(duration: 0.15)) { hovering = inside } }
        .help(enabled ? "Pause coaching (⇧⌘P)" : "Resume coaching (⇧⌘P)")
        .accessibilityLabel(enabled ? "Pause coaching" : "Resume coaching")
        .accessibilityValue(status)
    }
}

/// A plain grouped panel for free-form content.
struct Card<Content: View>: View {
    /// Lays brandWash over the surface. Only for brand moments, such as empty states.
    var wash = false
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(wash ? Color.brandWash : .clear))
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }
}

extension ToastModel {
    static var sample: ToastModel {
        ToastModel(style: .hint, bundleID: "com.apple.finder", symbol: "folder", eyebrow: "Use the shortcut next time",
                   title: "New Folder", keycapGroups: [["⇧", "⌘", "N"]],
                   footer: "Finder · picked from a menu 3× · shortcut used 1×")
    }
}

// MARK: - Overview

struct OverviewView: View {
    @ObservedObject private var store = StatsStore.shared
    @ObservedObject private var permission = Permission.shared
    @ObservedObject private var updates = Updates.shared
    @ObservedObject private var coach = Coach.shared
    @AppStorage(Prefs.Key.enabled) private var enabled = true
    @State private var filter = 0

    private var records: [HintRecord] {
        let all = store.records.values.filter {
            switch filter {
            case 1: $0.isLearned
            case 2: $0.alreadyKnown
            default: !$0.isKnown
            }
        }
        return all.sorted { ($0.shown, $0.lastShown ?? .distantPast) > ($1.shown, $1.lastShown ?? .distantPast) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !permission.trusted { PermissionCard() }
                if let version = updates.readyVersion { UpdateCard(version: version) }

                GroupedBox {
                    HStack(spacing: 0) {
                        Metric(value: store.totalShown, label: "Hints shown", symbol: "lightbulb.fill", color: .orange)
                        Divider().frame(height: 40)
                        Metric(value: store.totalUsed, label: "Shortcuts used", symbol: "keyboard.fill", color: .blue)
                        Divider().frame(height: 40)
                        Metric(value: store.learnedCount, label: "Learned here", symbol: "checkmark.seal.fill", color: .green)
                        Divider().frame(height: 40)
                        Metric(value: store.alreadyKnownCount, label: "Already knew", symbol: "star.fill", color: .purple)
                    }
                    .padding(.vertical, 14)
                }

                if store.records.isEmpty {
                    GettingStartedSection()
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            SectionLabel(["Still learning", "Learned here", "Already knew"][filter],
                                         detail: ["Sorted by how often you reached for the mouse.",
                                                  "Used \(HintRecord.learnedThreshold)× or more after a hint.",
                                                  "You were typing these before their first hint, so their hints stay quiet."][filter])
                            Spacer()
                            Picker("", selection: $filter) {
                                Text("Learning").tag(0)
                                Text("Learned").tag(1)
                                Text("Already knew").tag(2)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .fixedSize()
                        }
                        if records.isEmpty {
                            OverviewEmptyState(title: filter == 0 ? "Nothing left to learn right now." : "Nothing here yet.")
                        } else {
                            GroupedBox {
                                ForEach(records.prefix(60)) { RecordRow(record: $0) }
                            }
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 880, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .sectionGround()
        .toolbar { CoachingToolbarItem(status: statusText, dot: statusDot, enabled: $enabled) }
    }

    private var statusText: String {
        if !permission.trusted { return "Needs Accessibility access" }
        if !enabled { return "Paused" }
        return coach.isMonitoring ? "Coaching" : "Starting…"
    }

    /// Green while coaching, orange while blocked on Accessibility, gray when paused or starting.
    private var statusDot: Color {
        if !permission.trusted { return .orange }
        if enabled && coach.isMonitoring { return .green }
        return Color(nsColor: .tertiaryLabelColor)
    }
}

/// Overview's empty state is a brand moment: brandWash, with a hero ⌘ keycap leading it.
struct OverviewEmptyState: View {
    let title: String

    var body: some View {
        Card(wash: true) {
            HStack(spacing: 14) {
                KeycapRow(groups: [["⌘"]], size: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text("Hold ⌘ for a moment in any app to see every shortcut it has.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct Metric: View {
    let value: Int
    let label: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 14)).foregroundStyle(color)
                Text("\(value)").font(.system(size: 22, weight: .semibold)).monospacedDigit()
            }
            Text(label).font(.system(size: 11.5)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RecordRow: View {
    let record: HintRecord
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            HintIcon(bundleID: record.bundleID, symbol: symbol, size: 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(record.title).font(.system(size: 13)).lineLimit(1)
                    if record.muted {
                        Image(systemName: "bell.slash").font(.system(size: 10)).foregroundStyle(.tertiary).help("Muted")
                    }
                }
                Text(subtitle).font(.system(size: 11.5)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 12)
            if !record.matchKeys.isEmpty && !record.isKnown {
                ProgressView(value: record.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 56)
                    .help("\(record.used) of \(HintRecord.learnedThreshold) uses to learn")
            }
            KeycapRow(groups: record.keycapGroups, size: 12)
            Menu {
                Button(record.muted ? "Unmute Hint" : "Mute Hint") { StatsStore.shared.setMuted(record.id, !record.muted) }
                Button("Forget Hint", role: .destructive) { StatsStore.shared.remove(record.id) }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .opacity(hovering ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    private var subtitle: String {
        var parts = [record.appName, "missed \(record.shown)×"]
        if !record.matchKeys.isEmpty { parts.append("used \(record.used)×") }
        return parts.joined(separator: " · ")
    }

    private var symbol: String {
        switch record.kind {
        case .window: "macwindow"
        case .dialog: "return"
        case .dock: "dock.rectangle"
        case .habit: "arrow.left.arrow.right"
        case .text: "text.cursor"
        case .browser: "safari"
        case .finder: "folder"
        default: "keyboard"
        }
    }
}

struct PermissionCard: View {
    var body: some View {
        GroupedBox {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Accessibility access is off").font(.system(size: 13, weight: .semibold))
                    Text("Shortcut Coach can't see clicks or keys until it's allowed in Privacy & Security → Accessibility. If it's listed and switched on but nothing happens, remove it with − and add it again.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Button("Open Accessibility Settings") { Permission.shared.openSettings() }
                        Button("Relaunch") { relaunch() }
                    }
                    .controlSize(.small)
                    .padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }

    private func relaunch() {
        let url = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}

struct UpdateCard: View {
    let version: String

    var body: some View {
        GroupedBox {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Version \(version) is ready").font(.system(size: 13, weight: .semibold))
                    Text("It installs the next time you quit Shortcut Coach. Install it now and the app relaunches.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Install and Relaunch") { Updates.shared.installNow() }
                        .controlSize(.small)
                        .padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }
}

struct GettingStartedSection: View {
    private let steps: [(String, Color, String)] = [
        ("menubar.rectangle", .blue, "In Finder, choose File → New Folder with the mouse."),
        ("xmark", .red, "Close a window with its red button, or click a running app in the Dock."),
        ("arrow.left.arrow.right", .orange, "Press Ctrl+C in a text field, out of Windows habit."),
        ("command", .purple, "Hold ⌘ for a second in any app to see all of its shortcuts."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Get started", detail: "Try any of these and your first hints show up here.")
                Spacer()
                Button("Preview a Hint") { Toast.shared.show(.sample) }
                    .controlSize(.small)
            }
            GroupedBox {
                ForEach(steps, id: \.2) { symbol, color, text in
                    HStack(spacing: 12) {
                        IconTile(symbol: symbol, color: color, size: 22)
                        Text(text).font(.system(size: 13))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }
        }
    }
}
