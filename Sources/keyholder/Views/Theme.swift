import SwiftUI
import AppKit

/// Monochrome palette matching the KeyHolder website: warm paper + near-black ink
/// in light mode, inverted (coal + bone) in dark mode.
enum KHTheme {
    /// Window / popover background.
    static let paper = dynamicColor(
        light: NSColor(srgbRed: 244/255, green: 243/255, blue: 239/255, alpha: 1),
        dark: NSColor(srgbRed: 18/255, green: 18/255, blue: 18/255, alpha: 1)
    )

    /// Slightly recessed surface (hovered rows, footer).
    static let paperSoft = dynamicColor(
        light: NSColor(srgbRed: 236/255, green: 235/255, blue: 230/255, alpha: 1),
        dark: NSColor(srgbRed: 26/255, green: 26/255, blue: 26/255, alpha: 1)
    )

    /// Primary foreground; flips with appearance so opacity tiers work in both modes.
    static let ink = dynamicColor(
        light: NSColor(srgbRed: 18/255, green: 18/255, blue: 18/255, alpha: 1),
        dark: NSColor(srgbRed: 244/255, green: 243/255, blue: 239/255, alpha: 1)
    )

    /// Raised field background (search, form inputs).
    static let field = dynamicColor(
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.6),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.06)
    )

    static let ink60 = ink.opacity(0.6)
    static let ink40 = ink.opacity(0.4)
    static let ink12 = ink.opacity(0.12)
    static let ink06 = ink.opacity(0.06)

    private static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
}

extension Font {
    /// Small uppercase monospaced label, as used for COPY / footer text on the site.
    static let khMonoLabel = Font.system(size: 10, weight: .medium, design: .monospaced)
    /// Monospaced secondary line under each platform name.
    static let khMonoSub = Font.system(size: 11, design: .monospaced)
}
