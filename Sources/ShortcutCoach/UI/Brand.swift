import AppKit
import SwiftUI

/// Colors sampled from the app icon. They're for moments only (the onboarding welcome, the “Shortcut learned”
/// milestone, empty states), never chrome, buttons or body text.
extension Color {
    static let brandIndigo = Color(.sRGB, red: 0x89 / 255, green: 0x88 / 255, blue: 0xF8 / 255)
    static let brandViolet = Color(.sRGB, red: 0xB9 / 255, green: 0x86 / 255, blue: 0xF4 / 255)
    static let brandSpark = Color(.sRGB, red: 0xFF / 255, green: 0xE2 / 255, blue: 0x70 / 255)

    /// brandIndigo at 12% in Aqua, 18% in Dark Aqua: the ground behind a brand moment. Text on it stays .primary/.secondary.
    static let brandWash = Color(nsColor: NSColor(name: "brandWash") { appearance in
        let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return NSColor(srgbRed: 0x89 / 255, green: 0x88 / 255, blue: 0xF8 / 255, alpha: dark ? 0.18 : 0.12)
    })

    /// Ground under the scrolling main-window sections, a step darker than the boxes on it in both appearances so
    /// they lift off it by tone: underPageBackgroundColor (#f6f6f6) in Aqua, #141414 in Dark Aqua (boxes are #1e1e1e).
    static let contentGround = Color(nsColor: NSColor(name: "contentGround") { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(srgbRed: 0x14 / 255, green: 0x14 / 255, blue: 0x14 / 255, alpha: 1)
            : .underPageBackgroundColor
    })
}

/// The “Shortcut learned” icon: a white seal on a brandIndigo disc, with the icon's spark on its shoulder.
struct LearnedIcon: View {
    var symbol = "checkmark.seal.fill"
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.brandIndigo))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "sparkle")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.brandSpark)
                    .offset(x: 3, y: -2)
            }
    }
}
