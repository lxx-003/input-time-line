import SwiftUI

// MARK: - Plush Switch (knob stretches on press, green gradient fades in)

struct PlushSwitch: View {
    @Binding var isOn: Bool
    var size: SwitchSize = .regular

    enum SwitchSize {
        case regular
        case small

        var width: CGFloat { self == .regular ? 44 : 36 }
        var height: CGFloat { self == .regular ? 26 : 22 }
        var knob: CGFloat { self == .regular ? 22 : 18 }
        var stretch: CGFloat { self == .regular ? 4 : 3 }
    }

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        let padding = (size.height - size.knob) / 2
        let knobWidth = isPressed ? size.knob + size.stretch : size.knob
        let maxOffset = (size.width - knobWidth) / 2 - padding

        ZStack {
            Capsule()
                .fill(isHovered && !isOn ? PlushTheme.fillStrong : PlushTheme.controlOff)

            Capsule()
                .fill(PlushTheme.selectHorizontalGradient)
                .opacity(isOn ? 1 : 0)
                .brightness(isHovered && isOn ? 0.04 : 0)

            Circle()
                .fill(Color.white)
                .frame(width: knobWidth, height: size.knob)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.18), radius: 2.5, x: 0, y: 1)
                .scaleEffect(isHovered && !isPressed ? 1.05 : 1.0)
                .offset(x: isOn ? maxOffset : -maxOffset)
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Capsule())
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(PlushTheme.spring, value: isOn)
        .animation(PlushTheme.spring, value: isPressed)
        .animation(PlushTheme.fastFade, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed { isPressed = true }
                }
                .onEnded { value in
                    isPressed = false
                    if abs(value.translation.width) < 30 && abs(value.translation.height) < 30 {
                        isOn.toggle()
                    }
                }
        )
        .accessibilityElement()
        .accessibilityLabel("记录开关")
        .accessibilityValue(isOn ? "已开启" : "已暂停")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Plush Gliding Pill Segmented Tabs

struct PlushTabOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    let count: Int?
    let dotColor: Color?

    var id: Value { value }
}

struct PlushSegmentedTabs<Value: Hashable>: View {
    let options: [PlushTabOption<Value>]
    @Binding var selection: Value
    @Namespace private var pillNamespace
    @State private var hoveredValue: Value?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options) { option in
                let isSelected = option.value == selection
                let isHovered = hoveredValue == option.value

                Button {
                    withAnimation(PlushTheme.spring) {
                        selection = option.value
                    }
                } label: {
                    HStack(spacing: 5) {
                        if let dotColor = option.dotColor {
                            Circle()
                                .fill(dotColor)
                                .frame(width: 6, height: 6)
                        }

                        Text(option.title)
                            .font(PlushTheme.rounded(12, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? PlushTheme.ink : (isHovered ? PlushTheme.ink : PlushTheme.ink2))

                        if let count = option.count {
                            Text("\(count)")
                                .font(PlushTheme.rounded(10.5, weight: .semibold).monospacedDigit())
                                .foregroundStyle(isSelected ? PlushTheme.ink2 : PlushTheme.ink3)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? PlushTheme.fill : PlushTheme.panelTint.opacity(0.65))
                                )
                                .plushNumericTransition()
                        }
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5.5)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(PlushTheme.surfaceElevated)
                                .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
                                .matchedGeometryEffect(id: "plush-tab-pill", in: pillNamespace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoveredValue = hovering ? option.value : (hoveredValue == option.value ? nil : hoveredValue)
                }
            }
        }
        .padding(3.5)
        .background(
            Capsule()
                .fill(PlushTheme.fillStrong)
        )
    }
}

// MARK: - Plush Odometer Counter Stepper (inspired by plush-ui Counter)

struct PlushCounterStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var unit: String = ""

    var body: some View {
        HStack(spacing: 10) {
            Button {
                if value > range.lowerBound {
                    withAnimation(PlushTheme.spring) {
                        value -= 1
                    }
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(PlushCircleIconButtonStyle(diameter: 28, variant: .secondary))
            .disabled(value <= range.lowerBound)

            HStack(spacing: 2) {
                Text("\(value)")
                    .font(PlushTheme.rounded(16, weight: .semibold).monospacedDigit())
                    .foregroundStyle(PlushTheme.ink)
                    .plushNumericTransition()

                if !unit.isEmpty {
                    Text(unit)
                        .font(PlushTheme.rounded(12, weight: .medium))
                        .foregroundStyle(PlushTheme.ink2)
                }
            }
            .frame(minWidth: 44)

            Button {
                if value < range.upperBound {
                    withAnimation(PlushTheme.spring) {
                        value += 1
                    }
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(PlushCircleIconButtonStyle(diameter: 28, variant: .secondary))
            .disabled(value >= range.upperBound)
        }
    }
}

// MARK: - Plush Status Pill (Black pill with green disc or warning)

struct PlushStatusBadge: View {
    let title: String
    let dotColor: Color
    var isActive: Bool = true
    var darkStyle: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
                .shadow(color: isActive ? dotColor.opacity(0.65) : .clear, radius: 4)

            Text(title)
                .font(PlushTheme.rounded(11.5, weight: .semibold))
                .foregroundStyle(darkStyle ? PlushTheme.onAccent : PlushTheme.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(darkStyle ? PlushTheme.accent : PlushTheme.surfaceElevated)
        )
        .shadow(
            color: darkStyle ? .clear : Color.black.opacity(0.05),
            radius: 3,
            x: 0,
            y: 1
        )
    }
}
