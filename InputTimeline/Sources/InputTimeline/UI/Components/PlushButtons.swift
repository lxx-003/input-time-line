import SwiftUI

// MARK: - Plush Button Styles

enum PlushButtonVariant {
    case primary   // Black ink pill
    case surface   // White card-shadow pill
    case secondary // Soft grey fill pill
    case danger    // Red danger pill
    case ghost     // Transparent with hover fill
}

enum PlushButtonSize {
    case xs
    case sm
    case md

    var height: CGFloat {
        switch self {
        case .xs: return 28
        case .sm: return 32
        case .md: return 38
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .xs: return 11
        case .sm: return 14
        case .md: return 18
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .xs: return 11.5
        case .sm: return 12.5
        case .md: return 13.5
        }
    }
}

struct PlushPillButtonStyle: ButtonStyle {
    var variant: PlushButtonVariant = .primary
    var size: PlushButtonSize = .sm
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PlushTheme.rounded(size.fontSize, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, size.horizontalPadding)
            .frame(minHeight: size.height)
            .background(backgroundView(isPressed: configuration.isPressed))
            .clipShape(Capsule())
            .shadow(
                color: variant == .surface ? Color.black.opacity(isHovered ? 0.10 : 0.05) : .clear,
                radius: isHovered ? 8 : 3,
                x: 0,
                y: isHovered ? 3 : 1
            )
            .scaleEffect(configuration.isPressed && isEnabled ? 0.95 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.45)
            .animation(PlushTheme.spring, value: configuration.isPressed)
            .animation(PlushTheme.fastFade, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: return PlushTheme.onAccent
        case .surface, .secondary, .ghost: return PlushTheme.ink
        case .danger: return .white
        }
    }

    @ViewBuilder
    private func backgroundView(isPressed: Bool) -> some View {
        switch variant {
        case .primary:
            Capsule().fill(isHovered ? PlushTheme.accentHover : PlushTheme.accent)
        case .surface:
            Capsule().fill(isPressed ? PlushTheme.fill : PlushTheme.surfaceElevated)
        case .secondary:
            Capsule().fill(isPressed ? PlushTheme.panelTint : (isHovered ? PlushTheme.fillStrong : PlushTheme.fill))
        case .danger:
            Capsule().fill(PlushTheme.danger.opacity(isHovered ? 0.88 : 1.0))
        case .ghost:
            Capsule().fill(isPressed ? PlushTheme.fillStrong : (isHovered ? PlushTheme.fill : .clear))
        }
    }
}

struct PlushCircleIconButtonStyle: ButtonStyle {
    var diameter: CGFloat = 28
    var variant: PlushButtonVariant = .secondary
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: diameter, height: diameter)
            .foregroundStyle(foregroundColor)
            .background(backgroundCircle(isPressed: configuration.isPressed))
            .clipShape(Circle())
            .shadow(
                color: variant == .surface ? Color.black.opacity(isHovered ? 0.11 : 0.05) : .clear,
                radius: isHovered ? 6 : 2.5,
                x: 0,
                y: isHovered ? 2 : 1
            )
            .scaleEffect(
                configuration.isPressed && isEnabled
                ? 0.86
                : (isHovered && isEnabled ? 1.06 : 1.0)
            )
            .opacity(isEnabled ? 1.0 : 0.45)
            .animation(PlushTheme.spring, value: configuration.isPressed)
            .animation(PlushTheme.spring, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: return PlushTheme.onAccent
        case .surface, .secondary, .ghost: return PlushTheme.ink
        case .danger: return .white
        }
    }

    @ViewBuilder
    private func backgroundCircle(isPressed: Bool) -> some View {
        switch variant {
        case .primary:
            Circle().fill(isHovered ? PlushTheme.accentHover : PlushTheme.accent)
        case .surface:
            Circle().fill(isPressed ? PlushTheme.fill : PlushTheme.surfaceElevated)
        case .secondary:
            Circle().fill(isPressed ? PlushTheme.panelTint : (isHovered ? PlushTheme.fillStrong : PlushTheme.fill))
        case .danger:
            Circle().fill(PlushTheme.danger)
        case .ghost:
            Circle().fill(isPressed ? PlushTheme.fillStrong : (isHovered ? PlushTheme.fill : .clear))
        }
    }
}
