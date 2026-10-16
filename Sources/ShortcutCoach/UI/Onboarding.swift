import AppKit
import SwiftUI

/// First-run welcome tour: what the app does, permission, choices (with recommendations), and a live "try it".
final class Onboarding: NSObject, NSWindowDelegate {
    static let shared = Onboarding()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: OnboardingView.size.width, height: OnboardingView.size.height),
                             styleMask: [.titled, .closable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.contentViewController = NSHostingController(rootView: OnboardingView { [weak self] in self?.window?.close() })
            w.center()
            window = w
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        Prefs.d.set(true, forKey: Prefs.Key.hasOnboarded)
        window = nil
        (NSApp.delegate as? AppDelegate)?.showWindow(nil)
    }
}

struct OnboardingView: View {
    static let size = CGSize(width: 640, height: 580)

    let onFinish: () -> Void
    /// Off only for the selftest's previews: ImageRenderer leaves ScrollView content blank.
    private let scrolls: Bool
    @State private var step: Int
    private let titles = ["Welcome", "Permission", "What to coach", "Hints & tips", "Try it"]

    init(startAt step: Int = 0, scrolls: Bool = true, onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        self.scrolls = scrolls
        _step = State(initialValue: step)
    }

    var body: some View {
        VStack(spacing: 0) {
            ProgressSegments(count: titles.count, current: step)
                .padding(.horizontal, 40)
                .padding(.top, 34)

            if scrolls {
                // Step content scrolls inside a fixed area, so a taller step can never push the footer down.
                ScrollView { stepContent }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(maxHeight: .infinity)
            } else {
                // Unscrolled, a step taller than the window grows the view instead, so a preview shows all of it.
                stepContent.frame(maxHeight: .infinity, alignment: .top)
            }

            Divider().opacity(0.6)

            HStack(spacing: 8) {
                if step < titles.count - 1 {
                    Button("Skip Tour", action: onFinish)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if step > 0 {
                    Button("Back") { step -= 1 }
                        .controlSize(.large)
                }
                Button(step == titles.count - 1 ? "Done" : "Continue") {
                    if step == titles.count - 1 { onFinish() } else { step += 1 }
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
        }
        .frame(width: Self.size.width, height: scrolls ? Self.size.height : nil)
        .frame(minHeight: Self.size.height)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var stepContent: some View {
        Group {
            switch step {
            case 0: WelcomeStep()
            case 1: PermissionStep()
            case 2: ScopeStep()
            case 3: HintsStep()
            default: TryItStep()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, 40)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }
}

private struct ProgressSegments: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? Color.accentColor : Color.primary.opacity(0.1))
                    .frame(height: 3)
            }
        }
        .animation(.easeOut(duration: 0.2), value: current)
    }
}

private struct StepTitle: View {
    let symbol: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            IconTile(symbol: symbol, color: color, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 22, weight: .semibold))
                Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 20)
    }
}

/// A grouped-box row: title, explanation, trailing control.
private struct OptionRow<Trailing: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                Text(detail).font(.system(size: 11.5)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Steps

struct WelcomeStep: View {
    private let colors: [Color] = [.blue, .orange, .purple, .green]
    private let features: [(String, String, String)] = [
        ("cursorarrow.click", "Hints when you use the mouse",
         "Pick a menu item or click a button that has a shortcut, and a small note shows you the keys."),
        ("arrow.left.arrow.right", "Windows habits, translated",
         "Press Ctrl+C, Alt+F4 or Home out of habit and it shows the Mac equivalent."),
        ("command", "Hold ⌘ for a cheat sheet",
         "Hold ⌘ for a moment in any app to see every shortcut it has."),
        ("chart.bar.fill", "Progress you can see",
         "It tracks what you still do by mouse, and goes quiet once a shortcut sticks."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // A brand moment: the header sits on brandWash, and a hero keycap leads it.
            HStack(alignment: .center, spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    // Keys on the right of the title, like a toast, so the subtitle keeps the full width.
                    HStack(alignment: .center, spacing: 12) {
                        Text("Welcome to Shortcut Coach").font(.system(size: 22, weight: .semibold))
                        Spacer(minLength: 0)
                        KeycapRow(groups: [["⇧", "⌘", "N"]], size: 22)
                    }
                    Text("Learn macOS shortcuts by doing, not by memorizing lists.")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.brandWash))
            .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(features.enumerated()), id: \.element.1) { i, f in
                    let (symbol, title, detail) = f
                    HStack(alignment: .top, spacing: 14) {
                        IconTile(symbol: symbol, color: colors[i], size: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(.system(size: 13, weight: .medium))
                            Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Button("Preview a hint") { Toast.shared.show(.sample) }
                .buttonStyle(.link)
                .padding(.top, 24)
                .padding(.leading, 44)
        }
    }
}

private struct PermissionStep: View {
    @ObservedObject private var permission = Permission.shared
    @ObservedObject private var coach = Coach.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepTitle(symbol: "hand.raised.fill", color: .orange, title: "Allow Accessibility access",
                      subtitle: "Shortcut Coach uses it to see which menu item or button you clicked and which keys you pressed.")

            GroupedBox {
                HStack(spacing: 12) {
                    Image(systemName: permission.trusted ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(permission.trusted ? Color.green : Color.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(permission.trusted ? "Access granted" : "Not allowed yet")
                            .font(.system(size: 13, weight: .medium))
                        Text(permission.trusted
                             ? (coach.isMonitoring ? "Coaching is on." : "Starting…")
                             : "Turn on Shortcut Coach in Privacy & Security → Accessibility. This updates by itself.")
                            .font(.system(size: 11.5)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !permission.trusted {
                        Button("Open Settings") { Permission.shared.openSettings() }
                    }
                }
                .padding(12)
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock").foregroundStyle(.secondary)
                Text("Everything stays on this Mac. Nothing is sent anywhere, and the text you type is never recorded — only shortcut keys and which control you clicked.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
        .onAppear { if !permission.trusted { Permission.shared.startPolling() } }
    }
}

private struct ScopeStep: View {
    @AppStorage(Prefs.Key.appleAppsOnly) private var appleAppsOnly = true
    @AppStorage(Prefs.Key.hintWindowsHabits) private var habits = true
    @AppStorage(Prefs.Key.hintTextEditing) private var textEditing = true
    @AppStorage(Prefs.Key.quietKnown) private var quietKnown = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StepTitle(symbol: "scope", color: .blue, title: "Choose where to coach",
                      subtitle: "Everything here can be changed later in Settings.")

            VStack(spacing: 8) {
                ScopeOption(selected: appleAppsOnly, title: "Apple apps and macOS", recommended: true,
                            detail: "Finder, Safari, Mail, Notes, System Settings and the Dock, plus window buttons and dialogs in every app. These follow macOS conventions closely, so hints are reliable.") {
                    appleAppsOnly = true
                }
                ScopeOption(selected: !appleAppsOnly, title: "All apps", recommended: false,
                            detail: "Also coaches menus and toolbar buttons in apps like Chrome, Slack or your IDE.",
                            warning: appleAppsOnly ? nil : "Third-party apps build their interfaces in many different ways, so some clicks can produce hints that don't match what you did. Worth trying once you're comfortable.") {
                    appleAppsOnly = false
                }
            }

            SectionLabel("Keyboard", detail: "On by default — we suggest leaving these on while you learn.")
                .padding(.top, 8)
            GroupedBox {
                OptionRow(title: "Windows keyboard habits",
                          detail: "Ctrl+C, Alt+F4, Home / End and friends, translated to the Mac way.") {
                    Toggle("", isOn: $habits).labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                OptionRow(title: "Faster text editing",
                          detail: "Holding an arrow or ⌫ suggests jumping by word or line instead.") {
                    Toggle("", isOn: $textEditing).labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                OptionRow(title: "Go quiet once I know a shortcut",
                          detail: "Hints come back only if you use the mouse 5 times in a row.") {
                    Toggle("", isOn: $quietKnown).labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
            }
        }
    }
}

private struct ScopeOption: View {
    let selected: Bool
    let title: String
    let recommended: Bool
    let detail: String
    var warning: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "circle.inset.filled" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title).font(.system(size: 13, weight: .medium))
                        if recommended { RecommendedTag() }
                    }
                    Text(detail).font(.system(size: 11.5)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    if let warning {
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(selected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: selected ? 1.5 : 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct HintsStep: View {
    @AppStorage(Prefs.Key.toastPosition) private var position = ToastPosition.bottomRight.rawValue
    @AppStorage(Prefs.Key.periodicTips) private var periodicTips = true
    @AppStorage(Prefs.Key.tipInterval) private var tipInterval = 45
    @AppStorage(Prefs.Key.holdOverlay) private var holdOverlay = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StepTitle(symbol: "bell.badge.fill", color: .pink, title: "Choose how hints appear",
                      subtitle: "Hints are small notes that fade on their own and never take focus from what you're doing.")

            SectionLabel("Position")
            HStack(spacing: 12) {
                ForEach(ToastPosition.allCases) { p in
                    CornerOption(position: p, selected: position == p.rawValue,
                                 recommended: p == .bottomRight) {
                        position = p.rawValue
                        Toast.shared.show(.sample)
                    }
                }
            }

            SectionLabel("Extras").padding(.top, 8)
            GroupedBox {
                OptionRow(title: "Hold ⌘ for a cheat sheet",
                          detail: "Shows every shortcut of the app in front.") {
                    Toggle("", isOn: $holdOverlay).labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                OptionRow(title: "Occasional Mac tips",
                          detail: "Only while you're active and no other hint is showing.") {
                    HStack(spacing: 10) {
                        if periodicTips {
                            Picker("", selection: $tipInterval) {
                                Text("Every 15 minutes").tag(15)
                                Text("Every 30 minutes").tag(30)
                                Text("Every 45 minutes (recommended)").tag(45)
                                Text("Every hour").tag(60)
                                Text("Every 2 hours").tag(120)
                            }
                            .labelsHidden()
                            .controlSize(.small)
                            .fixedSize()
                        }
                        Toggle("", isOn: $periodicTips).labelsHidden().toggleStyle(.switch).controlSize(.small)
                    }
                }
            }
        }
    }
}

/// A tiny screen with a toast in one corner; the recommended corner is labelled beneath it.
private struct CornerOption: View {
    let position: ToastPosition
    let selected: Bool
    let recommended: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: alignment) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 6)
                        Spacer()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(selected ? Color.accentColor : Color.primary.opacity(0.3))
                        .frame(width: 34, height: 10)
                        .padding(.horizontal, 7)
                        .padding(.top, 11)
                        .padding(.bottom, 7)
                }
                .frame(width: 118, height: 74)
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: selected ? 2 : 0.5))

                Text(position.label).font(.system(size: 12))
                    .foregroundStyle(selected ? .primary : .secondary)
                Group {
                    if recommended { RecommendedTag() } else { Text(" ").font(.system(size: 11)) }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var alignment: Alignment {
        switch position {
        case .bottomRight: .bottomTrailing
        case .bottomCenter: .bottom
        case .topRight: .topTrailing
        case .topCenter: .top
        }
    }
}

private struct TryItStep: View {
    @State private var sawHint = false
    @State private var usedShortcut = false
    @State private var openedOverlay = false
    @ObservedObject private var permission = Permission.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepTitle(symbol: "sparkles", color: .green, title: "Try it out",
                      subtitle: "Switch to Finder and do these. Each one checks off when Shortcut Coach sees it.")

            GroupedBox {
                CheckRow(done: sawHint, title: "Get a hint",
                         detail: "In Finder, choose File → New Folder with the mouse.")
                CheckRow(done: usedShortcut, title: "Use the shortcut",
                         detail: "Now press ⇧⌘N in Finder instead.")
                CheckRow(done: openedOverlay, title: "Open the cheat sheet",
                         detail: "In Finder or any other app, hold ⌘ for about a second.")
            }

            if !permission.trusted {
                Label("Accessibility access isn't on yet, so nothing can check off. Go back to the Permission step to allow it.",
                      systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12)).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Shortcut Coach lives in the menu bar. Its window has cheat sheets, a Windows-to-Mac guide, tips, and your progress.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .hintShown)) { _ in withAnimation { sawHint = true } }
        .onReceive(NotificationCenter.default.publisher(for: .shortcutUsed)) { _ in withAnimation { usedShortcut = true } }
        .onReceive(NotificationCenter.default.publisher(for: .overlayShown)) { _ in withAnimation { openedOverlay = true } }
    }
}

private struct CheckRow: View {
    let done: Bool
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundStyle(done ? Color.green : Color(nsColor: .tertiaryLabelColor))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                    .foregroundStyle(done ? .secondary : .primary)
                Text(detail).font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
