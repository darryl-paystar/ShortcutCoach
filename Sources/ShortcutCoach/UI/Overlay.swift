import AppKit
import SwiftUI

/// The hold-⌘ cheat sheet: every menu shortcut of the frontmost app, packed into columns.
/// Click-through, dismissed by the next key press, click, or app switch.
final class Overlay {
    static let shared = Overlay()

    private(set) var isVisible = false
    private var panel: FloatingPanel?
    private var host: NSHostingView<AnyView>?
    private var token = 0
    private var autoClose: DispatchWorkItem?

    func show(for app: NSRunningApplication) {
        token += 1
        let current = token
        let name = app.localizedName ?? "App"
        let bundleID = app.bundleIdentifier
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let limit = CGSize(width: min(1900, screen.visibleFrame.width * 0.9), height: screen.visibleFrame.height * 0.82)

        present(OverlayView(appName: name, bundleID: bundleID, layout: nil), on: screen)
        NotificationCenter.default.post(name: .overlayShown, object: nil)
        MenuIndex.shared.entry(pid: app.processIdentifier, maxAge: 30) { entry in
            let layout = OverlayLayout(items: entry.items, limit: limit)
            DispatchQueue.main.async {
                guard current == self.token, self.isVisible else { return }
                self.present(OverlayView(appName: name, bundleID: bundleID, layout: layout), on: screen)
            }
        }
    }

    func dismiss() {
        guard isVisible, let panel else { return }
        isVisible = false
        token += 1
        autoClose?.cancel()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            if self?.isVisible == false { panel.orderOut(nil) }
        })
    }

    private func present(_ view: OverlayView, on screen: NSScreen) {
        if panel == nil {
            let p = FloatingPanel()
            p.ignoresMouseEvents = true
            p.level = .popUpMenu
            let h = NSHostingView(rootView: AnyView(EmptyView()))
            p.contentView = h
            panel = p
            host = h
        }
        guard let panel, let host else { return }
        host.rootView = AnyView(view)
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        let vf = screen.visibleFrame
        let frame = CGRect(x: (vf.midX - size.width / 2).rounded(), y: (vf.midY - size.height / 2).rounded(),
                           width: size.width, height: size.height)
        panel.setFrame(frame, display: true)
        if !isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                panel.animator().alphaValue = 1
            }
            isVisible = true
        }
        autoClose?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        autoClose = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 45, execute: work)
    }
}

/// Packs menu sections into columns that fit on screen without scrolling (the panel is click-through).
struct OverlayLayout {
    struct Section: Identifiable {
        let id: String
        let title: String
        var rows: [MenuShortcut]
        var hidden = 0
    }

    static let columnWidth: CGFloat = 268
    static let rowHeight: CGFloat = 21

    var columns: [[Section]] = []
    var totalShortcuts = 0
    var overflow = 0

    init(items: [MenuShortcut], limit: CGSize) {
        var order: [String] = []
        var grouped: [String: [MenuShortcut]] = [:]
        for item in items where item.combo != nil && item.menu != "Apple" {
            if grouped[item.menu] == nil { order.append(item.menu) }
            grouped[item.menu, default: []].append(item)
        }
        totalShortcuts = grouped.values.reduce(0) { $0 + $1.count }

        let maxColumns = max(1, Int(limit.width / (Self.columnWidth + 16)))
        let capacity = max(8, Int((limit.height - 90) / Self.rowHeight))
        var cols: [[Section]] = [[]]
        var used = 0
        for (i, menu) in order.enumerated() {
            var s = Section(id: menu, title: menu, rows: grouped[menu] ?? [])
            let maxRows = capacity - 2
            if s.rows.count > maxRows {
                s.hidden = s.rows.count - (maxRows - 1)
                s.rows = Array(s.rows.prefix(maxRows - 1))
            }
            let height = s.rows.count + 2 + (s.hidden > 0 ? 1 : 0)
            if used + height > capacity, !(cols.last?.isEmpty ?? true) {
                if cols.count == maxColumns {
                    overflow = order[i...].reduce(0) { $0 + (grouped[$1]?.count ?? 0) }
                    break
                }
                cols.append([])
                used = 0
            }
            cols[cols.count - 1].append(s)
            used += height
        }
        columns = cols.filter { !$0.isEmpty }
    }
}

struct OverlayView: View {
    let appName: String
    let bundleID: String?
    let layout: OverlayLayout?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                HintIcon(bundleID: bundleID, symbol: "keyboard", size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(appName) shortcuts").font(.system(size: 16, weight: .semibold))
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let layout {
                if layout.columns.isEmpty {
                    Text("This app doesn't expose any menu shortcuts.")
                        .foregroundStyle(.secondary)
                        .frame(width: 360, alignment: .leading)
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(Array(layout.columns.enumerated()), id: \.offset) { _, column in
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(column) { section in
                                    SectionView(section: section)
                                }
                            }
                            .frame(width: OverlayLayout.columnWidth, alignment: .topLeading)
                        }
                    }
                }
                if layout.overflow > 0 {
                    Text("+\(layout.overflow) more — see Shortcut Coach → App Shortcuts for the full list.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Reading menus…").foregroundStyle(.secondary)
                }
                .frame(width: 360, alignment: .leading)
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 24)
        .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 10)
        .padding(30)
    }

    private var subtitle: String {
        if let layout { return "\(layout.totalShortcuts) shortcuts · press any key or click to close" }
        return "Hold ⌘ to show this any time"
    }

    private struct SectionView: View {
        let section: OverlayLayout.Section

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(section.title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                    .frame(height: OverlayLayout.rowHeight, alignment: .bottomLeading)
                ForEach(section.rows) { item in
                    HStack(spacing: 8) {
                        Text(item.path.count > 2 ? item.subpath : item.title)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 6)
                        if let combo = item.combo {
                            KeycapRow(groups: [combo.keycaps], size: 10)
                        }
                    }
                    .frame(height: OverlayLayout.rowHeight)
                }
                if section.hidden > 0 {
                    Text("+\(section.hidden) more")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .frame(height: OverlayLayout.rowHeight)
                }
            }
        }
    }
}
