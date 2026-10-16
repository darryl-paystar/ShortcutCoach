import AppKit
import SwiftUI

struct ToastAction: Identifiable {
    let id = UUID()
    let title: String
    let run: () -> Void
}

struct ToastModel {
    enum Style { case hint, habit, celebrate, learned, tip, suggestion }

    var style: Style
    var bundleID: String?
    var symbol: String
    var eyebrow: String
    var title: String
    var keycapGroups: [[String]] = []
    var joiner = "or"
    var message: String?
    var footer: String?
    /// Set when the toast can be muted ("don't show this hint again").
    var hintID: String?
    var actions: [ToastAction] = []

    /// Color is reserved for meaning: green for progress, orange for a habit to unlearn. The learned milestone
    /// is a brand moment instead (see `LearnedIcon` and `Color.brandWash`), so it has no tint.
    var tint: Color? {
        switch style {
        case .habit: .orange
        case .celebrate: .green
        case .tip: .yellow
        default: nil
        }
    }

    static func hint(_ h: Hint, record r: HintRecord, reminder: Bool = false) -> ToastModel {
        let verb: String
        switch h.kind {
        case .menu: verb = "picked from a menu"
        case .habit, .text: verb = "seen"
        default: verb = "clicked"
        }
        var footer = "\(h.appName) · \(verb) \(r.shown)×"
        if !r.matchKeys.isEmpty { footer += " · shortcut used \(r.used)×" }
        let eyebrow = reminder ? "Reminder — \(r.mouseStreak) mouse uses in a row" : h.eyebrow
        return ToastModel(style: h.kind == .habit ? .habit : .hint, bundleID: h.bundleID, symbol: h.symbol,
                          eyebrow: eyebrow, title: h.title, keycapGroups: h.keycapGroups,
                          message: h.message, footer: footer, hintID: h.id)
    }

    static func celebration(_ r: HintRecord) -> ToastModel {
        let learned = r.used >= HintRecord.learnedThreshold
        let message: String
        switch r.used {
        case 1: message = "First time using the shortcut instead of the mouse. That's how it sticks."
        case HintRecord.learnedThreshold: message = "\(r.used) times now — this one's learned."
        default: message = "\(r.used) times and counting."
        }
        // The use that makes it stick is a brand moment; first use and later counts stay green progress.
        let style: Style = r.used == HintRecord.learnedThreshold ? .learned : .celebrate
        return ToastModel(style: style, bundleID: nil, symbol: learned ? "checkmark.seal.fill" : "checkmark.circle.fill",
                          eyebrow: learned ? "Shortcut learned" : "Nice — you used the shortcut",
                          title: r.title, keycapGroups: r.keycapGroups, message: message, footer: r.appName)
    }

    static func tip(_ tip: Tip) -> ToastModel {
        ToastModel(style: .tip, bundleID: nil, symbol: "lightbulb", eyebrow: "Mac tip · \(tip.category)",
                   title: tip.title, keycapGroups: tip.shortcuts.map(KeyCombo.keycaps(from:)), joiner: tip.joiner,
                   message: tip.body)
    }

    static func noShortcut(appName: String, bundleID: String?, title: String, path: [String], count: Int) -> ToastModel {
        let menu = path.first ?? "a"
        return ToastModel(
            style: .suggestion, bundleID: bundleID, symbol: "plus.square.dashed",
            eyebrow: "No shortcut yet", title: "“\(title)”",
            message: "You've chosen this from the \(menu) menu \(count)×. Give it your own shortcut: System Settings → Keyboard → Keyboard Shortcuts… → App Shortcuts → +, pick \(appName), and type the exact menu title.",
            footer: path.joined(separator: " → "),
            actions: [
                ToastAction(title: "Copy Title") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(title, forType: .string)
                },
                ToastAction(title: "Open Keyboard Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                },
            ])
    }
}

/// Floating, non-activating toast in a screen corner. One at a time; a new one replaces the old.
final class Toast {
    static let shared = Toast()

    private(set) var isVisible = false
    private var panel: FloatingPanel?
    private var host: HoverHostingView<AnyView>?
    private var dismissWork: DispatchWorkItem?
    private var duration: TimeInterval = 5
    private var hovering = false

    func show(_ model: ToastModel) {
        let (panel, host) = ensurePanel()
        var mute: (() -> Void)?
        if let id = model.hintID {
            mute = { [weak self] in
                StatsStore.shared.setMuted(id, true)
                self?.dismiss()
            }
        }
        host.rootView = AnyView(ToastView(model: model, onClose: { [weak self] in self?.dismiss() }, onMute: mute))
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        let position = Prefs.toastPosition
        let frame = Self.frame(for: size, position: position)

        if isVisible {
            panel.setFrame(frame, display: true)
            panel.alphaValue = 1
        } else {
            let from = position == .topRight || position == .topCenter ? 10.0 : -10.0
            panel.setFrame(frame.offsetBy(dx: 0, dy: from), display: false)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.22
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(frame, display: true)
                panel.animator().alphaValue = 1
            }
        }
        isVisible = true
        duration = Prefs.toastDuration + min(4, Double(model.message?.count ?? 0) / 45)
        scheduleDismiss()
    }

    func dismiss() {
        dismissWork?.cancel()
        guard isVisible, let panel else { return }
        isVisible = false
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            if self?.isVisible == false { panel.orderOut(nil) }
        })
    }

    private func scheduleDismiss() {
        dismissWork?.cancel()
        guard !hovering else { return }
        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func ensurePanel() -> (FloatingPanel, HoverHostingView<AnyView>) {
        if let panel, let host { return (panel, host) }
        let panel = FloatingPanel()
        let host = HoverHostingView(rootView: AnyView(EmptyView()))
        host.onHover = { [weak self] inside in
            guard let self else { return }
            hovering = inside
            if inside { dismissWork?.cancel() } else { duration = 2.5; scheduleDismiss() }
        }
        panel.contentView = host
        self.panel = panel
        self.host = host
        return (panel, host)
    }

    private static func frame(for size: CGSize, position: ToastPosition) -> CGRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let vf = screen.visibleFrame
        let x: CGFloat, y: CGFloat
        switch position {
        case .bottomRight: x = vf.maxX - size.width - 4; y = vf.minY + 4
        case .bottomCenter: x = vf.midX - size.width / 2; y = vf.minY + 12
        case .topRight: x = vf.maxX - size.width - 4; y = vf.maxY - size.height
        case .topCenter: x = vf.midX - size.width / 2; y = vf.maxY - size.height
        }
        return CGRect(x: x.rounded(), y: y.rounded(), width: size.width, height: size.height)
    }
}

/// Borderless panel that floats over everything (including full-screen apps) without stealing focus.
final class FloatingPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Hosting view that accepts the first click (the panel is never key) and reports hover.
final class HoverHostingView<V: View>: NSHostingView<V> {
    var onHover: ((Bool) -> Void)?
    private var area: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area { removeTrackingArea(area) }
        let a = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(a)
        area = a
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHover?(false)
    }
}

struct ToastView: View {
    let model: ToastModel
    let onClose: () -> Void
    let onMute: (() -> Void)?
    @State private var hovering = false

    private let indent: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Laid out like a menu item: what you did on the left, the keys on the right.
            HStack(alignment: .center, spacing: 12) {
                if model.style == .learned {
                    LearnedIcon(symbol: model.symbol, size: 28)
                } else {
                    HintIcon(bundleID: model.bundleID, symbol: model.symbol, size: 28, tint: model.tint)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.eyebrow)
                        .font(.system(size: 11))
                        .foregroundStyle(model.style == .tip ? .secondary : (model.tint ?? .secondary))
                        .lineLimit(1)
                    Text(model.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if !model.keycapGroups.isEmpty {
                    KeycapRow(groups: model.keycapGroups, size: 14, joiner: model.joiner)
                }
            }

            if let message = model.message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, indent)
            }
            if !model.actions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(model.actions) { action in
                        Button(action.title, action: action.run).controlSize(.small)
                    }
                }
                .padding(.leading, indent)
            }
            if model.footer != nil || onMute != nil {
                HStack(spacing: 8) {
                    if let footer = model.footer {
                        Text(footer)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    // Always shown on hints: after a repeat, muting is the control people look for.
                    if let onMute {
                        ToastIconButton(symbol: "bell.slash", help: "Don't show this hint again", action: onMute)
                            .padding(.vertical, -4)
                    }
                }
                .padding(.leading, indent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 380)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(model.style == .learned ? Color.brandWash : .clear))
        .glassCard(cornerRadius: 16)
        .overlay(alignment: .topTrailing) {
            // Close appears on hover only, so the resting toast stays clean.
            ToastIconButton(symbol: "xmark", help: "Dismiss", action: onClose)
                .padding(6)
                .background(Capsule().fill(.regularMaterial))
                .offset(x: 6, y: -10)
                .opacity(hovering ? 1 : 0)
        }
        .onHover { inside in withAnimation(.easeOut(duration: 0.15)) { hovering = inside } }
        .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 4)
        .padding(18)
    }
}

private struct ToastIconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(hover ? .primary : .secondary)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.primary.opacity(hover ? 0.1 : 0)))
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hover = $0 }
    }
}
