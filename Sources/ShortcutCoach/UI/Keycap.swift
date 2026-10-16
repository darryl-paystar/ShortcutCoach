import SwiftUI

/// A single key, drawn as a quiet keycap: subtle fill, hairline border, a 1 pt lower edge.
struct Keycap: View {
    let text: String
    var size: CGFloat = 13

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
        Text(text)
            .font(.system(size: size * (text.count > 1 ? 0.85 : 1), weight: .medium))
            .foregroundStyle(.primary.opacity(0.85))
            .padding(.horizontal, text.count > 1 ? size * 0.42 : 0)
            .frame(minWidth: size * 1.6, minHeight: size * 1.6)
            .background(shape.fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(shape.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
            .background(shape.fill(Color(nsColor: .separatorColor)).offset(y: 1))
    }
}

/// One or more key combinations: [["⇧","⌘","N"], ["⌃","⇥"]] → ⇧⌘N  or  ⌃⇥
struct KeycapRow: View {
    let groups: [[String]]
    var size: CGFloat = 13
    var joiner = "or"

    var body: some View {
        HStack(spacing: size * 0.35) {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                if index > 0 {
                    Text(joiner)
                        .font(.system(size: size * 0.8))
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: size * 0.2) {
                    ForEach(Array(group.enumerated()), id: \.offset) { _, key in
                        Keycap(text: key, size: size)
                    }
                }
            }
        }
        .fixedSize()
    }

    init(groups: [[String]], size: CGFloat = 13, joiner: String = "or") {
        self.groups = groups
        self.size = size
        self.joiner = joiner
    }

    /// Convenience for strings like ["⌘[", "⌘]"].
    init(shortcuts: [String], size: CGFloat = 13, joiner: String = "/") {
        self.groups = shortcuts.map(KeyCombo.keycaps(from:))
        self.size = size
        self.joiner = joiner
    }
}

/// Liquid Glass on macOS 26+, material elsewhere.
struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 18
    /// Offscreen rendering (self-test previews) can't draw glass or materials.
    nonisolated(unsafe) static var plain = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if Self.plain {
            content.background(Color(nsColor: .windowBackgroundColor), in: shape)
                .overlay(shape.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
        } else if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
        }
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius))
    }
}

/// App icon when known; otherwise a monochrome symbol on a neutral disc.
struct HintIcon: View {
    let bundleID: String?
    let symbol: String
    var size: CGFloat = 28
    var tint: Color? = nil

    var body: some View {
        if let img = Apps.icon(for: bundleID) {
            Image(nsImage: img)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            Image(systemName: symbol)
                .font(.system(size: size * 0.46, weight: .medium))
                .foregroundStyle(tint ?? .secondary)
                .frame(width: size, height: size)
                .background(Circle().fill((tint ?? .primary).opacity(0.1)))
        }
    }
}

/// A System Settings–style colored tile with a white glyph.
struct IconTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous).fill(color.gradient))
    }
}

// MARK: - Grouped containers (System Settings style)

/// A rounded group of rows separated by hairlines, like a grouped Form section.
struct GroupedBox<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Divider().padding(.leading, 12) }
                    row
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }
}

/// Small sentence-case heading above a grouped box.
struct SectionLabel: View {
    let title: String
    var detail: String? = nil

    init(_ title: String, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 13, weight: .semibold))
            if let detail {
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.leading, 2)
    }
}

/// Quiet inline "Recommended" marker, attached to the option it describes.
struct RecommendedTag: View {
    var body: some View {
        Text("Recommended")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .overlay(Capsule().strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }
}
