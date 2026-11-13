import AppKit
import SwiftUI

enum PlushTheme {
    // MARK: - Dynamic Light / Dark Colors (aligned with plush-ui tokens.css)

    private static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? dark : light
        })
    }

    private static func hex(_ hex: UInt32, alpha: CGFloat = 1.0) -> NSColor {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
    }

    // Surfaces (from back to front)
    static let bg = dynamicColor(light: hex(0xFBFBFA), dark: hex(0x141416))
    static let panel = dynamicColor(light: hex(0xF3F3F1), dark: hex(0x1B1B1E))
    static let panelTint = dynamicColor(light: hex(0xE9E9E6), dark: hex(0x232327))
    static let surface = dynamicColor(light: hex(0xFFFFFF), dark: hex(0x222226))
    static let surfaceElevated = dynamicColor(light: hex(0xFFFFFF), dark: hex(0x2A2A2F))
    static let fill = dynamicColor(light: hex(0xF0F0EE), dark: hex(0x27272B))
    static let fillStrong = dynamicColor(light: hex(0xE8E8E5), dark: hex(0x313136))
    static let line = dynamicColor(light: hex(0xE4E4E1), dark: hex(0xFFFFFF, alpha: 0.08))
    static let controlOff = dynamicColor(light: hex(0xE4E4E1), dark: hex(0x38383E))

    // Ink
    static let ink = dynamicColor(light: hex(0x141414), dark: hex(0xF5F5F7))
    static let ink2 = dynamicColor(light: hex(0x6E6E72), dark: hex(0xA1A1A6))
    static let ink3 = dynamicColor(light: hex(0xA3A3A6), dark: hex(0x6C6C72))

    // Accent (Monochrome ink buttons)
    static let accent = dynamicColor(light: hex(0x161616), dark: hex(0xF5F5F7))
    static let onAccent = dynamicColor(light: hex(0xFFFFFF), dark: hex(0x141414))
    static let accentHover = dynamicColor(light: hex(0x2E2E2E), dark: hex(0xE2E2E6))

    // Semantic Status
    static let success = dynamicColor(light: hex(0x2FC26B), dark: hex(0x34D175))
    static let warning = dynamicColor(light: hex(0xF5A524), dark: hex(0xFFB338))
    static let danger = dynamicColor(light: hex(0xF2473D), dark: hex(0xFF5A52))
    static let pink = dynamicColor(light: hex(0xEE4A92), dark: hex(0xFF5FA5))

    // Plush Green Gradient Selection
    static let selectA = Color(red: 0.086, green: 0.761, blue: 0.420) // #16C26B
    static let selectB = Color(red: 0.722, green: 0.902, blue: 0.180) // #B8E62E
    static let onSelect = Color(red: 0.078, green: 0.078, blue: 0.078) // #141414
    static let selectMark = dynamicColor(
        light: hex(0x16C26B, alpha: 0.24),
        dark: hex(0x16C26B, alpha: 0.34)
    )
    static let selectPlate = dynamicColor(
        light: hex(0x16C26B, alpha: 0.14),
        dark: hex(0x16C26B, alpha: 0.20)
    )

    static var selectGradient: LinearGradient {
        LinearGradient(
            colors: [selectA, selectB],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var selectHorizontalGradient: LinearGradient {
        LinearGradient(
            colors: [selectA, selectB],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // Event kind colors (harmonized with Plush)
    static let kindKeyboard = dynamicColor(light: hex(0x2563EB), dark: hex(0x60A5FA))
    static let kindCopy = dynamicColor(light: hex(0xF59E0B), dark: hex(0xFBBF24))
    static let kindPaste = dynamicColor(light: hex(0x16C26B), dark: hex(0x34D399))

    // MARK: - Radii (desktop-proportioned concentric system)

    enum Radius {
        static let panel: CGFloat = 24
        static let sheet: CGFloat = 22
        static let card: CGFloat = 18
        static let row: CGFloat = 14
        static let item: CGFloat = 10
        static let check: CGFloat = 8
    }

    // MARK: - Typography

    static func rounded(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func body(_ size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    // MARK: - Spring Motion Curves

    static let spring = Animation.spring(response: 0.32, dampingFraction: 0.76)
    static let softSpring = Animation.spring(response: 0.42, dampingFraction: 0.84)
    static let calmSpring = Animation.spring(response: 0.50, dampingFraction: 0.88)
    static let fastFade = Animation.easeOut(duration: 0.12)
    static let popSpring = Animation.spring(response: 0.24, dampingFraction: 0.65)
}

// MARK: - Fast Surface Shadow (rendered on background shape only, avoiding offscreen rendering of content)

struct PlushBackgroundSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat
    var background: Color
    var elevated: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let isDark = colorScheme == .dark
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(background)
                    .shadow(
                        color: Color.black.opacity(isDark ? (elevated ? 0.36 : 0.22) : (elevated ? 0.10 : 0.045)),
                        radius: elevated ? 12 : 6,
                        x: 0,
                        y: elevated ? 4 : 2
                    )
            )
    }
}

extension View {
    func plushSoftShadow(elevated: Bool = false) -> some View {
        self.shadow(
            color: Color.black.opacity(elevated ? 0.11 : 0.05),
            radius: elevated ? 12 : 6,
            x: 0,
            y: elevated ? 4 : 2
        )
    }

    func plushCardSurface(
        cornerRadius: CGFloat = PlushTheme.Radius.card,
        background: Color = PlushTheme.surface,
        elevated: Bool = false
    ) -> some View {
        modifier(
            PlushBackgroundSurfaceModifier(
                cornerRadius: cornerRadius,
                background: background,
                elevated: elevated
            )
        )
    }

    @ViewBuilder
    func plushNumericTransition() -> some View {
        if #available(macOS 13.0, *) {
            self.contentTransition(.numericText())
        } else {
            self
        }
    }
}
