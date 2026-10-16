import SwiftUI

struct SettingsView: View {
    @AppStorage(Prefs.Key.enabled) private var enabled = true
    @AppStorage(Prefs.Key.appleAppsOnly) private var appleAppsOnly = true
    @AppStorage(Prefs.Key.hintMenus) private var hintMenus = true
    @AppStorage(Prefs.Key.hintButtons) private var hintButtons = true
    @AppStorage(Prefs.Key.hintWindowControls) private var hintWindowControls = true
    @AppStorage(Prefs.Key.hintDialogs) private var hintDialogs = true
    @AppStorage(Prefs.Key.hintDock) private var hintDock = true
    @AppStorage(Prefs.Key.hintBrowser) private var hintBrowser = true
    @AppStorage(Prefs.Key.hintFinder) private var hintFinder = true
    @AppStorage(Prefs.Key.hintWindowsHabits) private var hintWindowsHabits = true
    @AppStorage(Prefs.Key.hintTextEditing) private var hintTextEditing = true
    @AppStorage(Prefs.Key.suggestCustomShortcuts) private var suggestCustom = true
    @AppStorage(Prefs.Key.noShortcutThreshold) private var noShortcutThreshold = 3
    @AppStorage(Prefs.Key.celebrate) private var celebrate = true
    @AppStorage(Prefs.Key.quietKnown) private var quietKnown = true
    @AppStorage(Prefs.Key.remindAfter) private var remindAfter = 5
    @AppStorage(Prefs.Key.cooldown) private var cooldown = 20.0
    @AppStorage(Prefs.Key.holdOverlay) private var holdOverlay = true
    @AppStorage(Prefs.Key.holdDelay) private var holdDelay = 1.2
    @AppStorage(Prefs.Key.periodicTips) private var periodicTips = true
    @AppStorage(Prefs.Key.tipInterval) private var tipInterval = 45
    @AppStorage(Prefs.Key.toastPosition) private var toastPosition = ToastPosition.bottomRight.rawValue
    @AppStorage(Prefs.Key.toastDuration) private var toastDuration = 5.0
    @AppStorage(Prefs.Key.debugLogging) private var debugLogging = false
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @ObservedObject private var updates = Updates.shared
    @State private var autoDownload = Updates.shared.downloadsAutomatically
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                Toggle("Coaching is on", isOn: $enabled)
                Toggle("Celebrate when I use a shortcut I was taught", isOn: $celebrate)
                LabeledContent("Don't repeat the same hint within") {
                    Picker("", selection: $cooldown) {
                        Text("no limit").tag(0.0)
                        Text("10 seconds").tag(10.0)
                        Text("20 seconds").tag(20.0)
                        Text("1 minute").tag(60.0)
                        Text("5 minutes").tag(300.0)
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
            } header: {
                Text("General")
            }

            Section {
                Toggle(isOn: $appleAppsOnly) {
                    Text("Apple apps and macOS only")
                    Text("Click hints only in Finder, Safari, Mail, System Settings and other Apple apps. Window buttons, dialogs and keyboard habits are coached everywhere.")
                }
                Toggle("Menu items chosen with the mouse", isOn: $hintMenus)
                Toggle("Toolbar buttons that match a menu command", isOn: $hintButtons)
                Toggle("Window buttons (close, minimize, full screen)", isOn: $hintWindowControls)
                Toggle("Dialog buttons (Return / Esc)", isOn: $hintDialogs)
                Toggle("Dock clicks (⌘⇥ and Spotlight)", isOn: $hintDock)
                Toggle("Browser tabs and address bar", isOn: $hintBrowser)
                Toggle("Finder sidebar, tabs and keys", isOn: $hintFinder)
                Toggle("Windows keyboard habits (Ctrl+C, Alt+F4, Home/End…)", isOn: $hintWindowsHabits)
                Toggle("Text editing (holding arrows or ⌫)", isOn: $hintTextEditing)
                Toggle("Suggest making a shortcut for menu items that have none", isOn: $suggestCustom)
                if suggestCustom {
                    Stepper("…after choosing the same item \(noShortcutThreshold)×", value: $noShortcutThreshold, in: 1...20)
                }
            } header: {
                Text("What to coach")
            }

            Section {
                Toggle(isOn: $quietKnown) {
                    Text("Stay quiet about shortcuts I already know")
                    Text("A shortcut counts as known once you've used it \(HintRecord.learnedThreshold)× after a hint, or if you were already typing it before its first hint.")
                }
                if quietKnown {
                    Picker("Remind me again after", selection: $remindAfter) {
                        Text("3 mouse uses in a row").tag(3)
                        Text("5 mouse uses in a row").tag(5)
                        Text("10 mouse uses in a row").tag(10)
                        Text("Never").tag(0)
                    }
                }
            } header: {
                Text("Shortcuts you know")
            } footer: {
                Text("Typing the shortcut resets the count, so a reminder only appears if you've drifted back to the mouse.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Toggle("Hold ⌘ to show the current app's shortcuts", isOn: $holdOverlay)
                if holdOverlay {
                    LabeledContent("Hold for") {
                        HStack {
                            Slider(value: $holdDelay, in: 0.6...2.5, step: 0.1).frame(width: 180)
                            Text(String(format: "%.1f s", holdDelay)).monospacedDigit().frame(width: 44, alignment: .trailing)
                        }
                    }
                }
            } header: {
                Text("Cheat-sheet overlay")
            }

            Section {
                Toggle("Show a tip every so often", isOn: $periodicTips)
                if periodicTips {
                    Picker("Every", selection: $tipInterval) {
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("45 minutes").tag(45)
                        Text("1 hour").tag(60)
                        Text("2 hours").tag(120)
                    }
                }
            } header: {
                Text("Tips")
            }

            Section {
                Picker("Position", selection: $toastPosition) {
                    ForEach(ToastPosition.allCases) { Text($0.label).tag($0.rawValue) }
                }
                LabeledContent("Stay on screen for") {
                    HStack {
                        Slider(value: $toastDuration, in: 2...12, step: 0.5).frame(width: 180)
                        Text(String(format: "%.1f s", toastDuration)).monospacedDigit().frame(width: 44, alignment: .trailing)
                    }
                }
                Button("Preview a Hint") { Toast.shared.show(.sample) }
            } header: {
                Text("Hint toasts")
            }

            AppListSection(key: Prefs.Key.habitExclusions, title: "Don't flag Windows-style keys in these apps",
                           footnote: "Keyboard-habit hints catch keys that mean something else on a Mac — Ctrl+C for copy, Home / End, Ctrl+← — and slow editing like holding an arrow or ⌫. In terminals and code editors those keys are correct (Ctrl+C stops a command, Home / End move the cursor), so these hints are off there. Mouse hints in these apps still work. A trailing * covers a whole family, e.g. com.jetbrains.* for every JetBrains IDE.")
            AppListSection(key: Prefs.Key.ignoredApps, title: "Never coach in these apps",
                           footnote: "No hints of any kind — mouse or keyboard — while one of these apps is in front.")

            if updates.isAvailable {
                Section {
                    if let version = updates.readyVersion {
                        LabeledContent {
                            Button("Install and Relaunch") { updates.installNow() }
                        } label: {
                            Text("Version \(version) is ready")
                            Text("Otherwise it installs the next time you quit.")
                        }
                    }
                    Toggle(isOn: $autoDownload) {
                        Text("Download updates automatically")
                        Text("New versions download in the background, and you choose when to install them. Off, you're asked before each download.")
                    }
                    .onChange(of: autoDownload) { updates.downloadsAutomatically = autoDownload }
                    LabeledContent("Version \(Updates.version)") {
                        Button("Check for Updates…") { updates.checkForUpdates(nil) }
                    }
                } header: {
                    Text("Updates")
                }
            }

            Section {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { LaunchAtLogin.set(launchAtLogin) }
                Toggle("Debug logging (records clicked UI elements)", isOn: $debugLogging)
                Button("Show the Welcome Tour Again") { Onboarding.shared.show() }
                HStack {
                    Button("Show Log in Finder") { NSWorkspace.shared.activateFileViewerSelecting([Log.url]) }
                    Spacer()
                    Button("Reset Statistics…", role: .destructive) { confirmReset = true }
                }
            } header: {
                Text("Advanced")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .sectionGround()
        .confirmationDialog("Reset all hint statistics?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { StatsStore.shared.reset() }
        } message: {
            Text("Missed and used counts, learned shortcuts and mutes are cleared.")
        }
    }
}

private struct AppListSection: View {
    let key: String
    let title: String
    let footnote: String
    @State private var list: [String]

    init(key: String, title: String, footnote: String) {
        self.key = key
        self.title = title
        self.footnote = footnote
        _list = State(initialValue: Prefs.d.stringArray(forKey: key) ?? [])
    }

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil && !list.contains($0.bundleIdentifier!) }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    var body: some View {
        Section {
            ForEach(list, id: \.self) { id in
                HStack(spacing: 8) {
                    if id.hasSuffix("*") {
                        Image(systemName: "asterisk.circle").frame(width: 18)
                        Text(id)
                    } else {
                        HintIcon(bundleID: id, symbol: "app.dashed", size: 18)
                        Text(Apps.name(for: id))
                        Text(id).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        list.removeAll { $0 == id }
                        Prefs.d.set(list, forKey: key)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            Menu("Add a Running App") {
                ForEach(runningApps, id: \.processIdentifier) { app in
                    Button(app.localizedName ?? app.bundleIdentifier!) {
                        list.append(app.bundleIdentifier!)
                        Prefs.d.set(list, forKey: key)
                    }
                }
            }
            .fixedSize()
        } header: {
            Text(title)
        } footer: {
            Text(footnote).font(.caption).foregroundStyle(.secondary)
        }
    }
}
