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

// MARK: - Plush Sonner Toast Banner

struct PlushToastMessage: Identifiable, Equatable {
    enum Tone: Equatable {
        case success
        case info
        case warning
        case error

        var color: Color {
            switch self {
            case .success: return PlushTheme.success
            case .info: return PlushTheme.accent
            case .warning: return PlushTheme.warning
            case .error: return PlushTheme.danger
            }
        }

        var icon: String {
            switch self {
            case .success: return "checkmark"
            case .info: return "info"
            case .warning: return "exclamationmark"
            case .error: return "xmark"
            }
        }
    }

    let id: UUID
    let title: String
    let subtitle: String?
    let tone: Tone

    init(id: UUID = UUID(), title: String, subtitle: String? = nil, tone: Tone = .success) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.tone = tone
    }
}

struct PlushToastBanner: View {
    let toast: PlushToastMessage
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(toast.tone.color)
                    .frame(width: 24, height: 24)

                Image(systemName: toast.tone.icon)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(toast.tone == .info ? PlushTheme.onAccent : Color.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(toast.title)
                    .font(PlushTheme.rounded(13, weight: .semibold))
                    .foregroundStyle(PlushTheme.ink)
                    .lineLimit(1)

                if let subtitle = toast.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(PlushTheme.rounded(11.5, weight: .medium))
                        .foregroundStyle(PlushTheme.ink2)
                        .lineLimit(1)
                }
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(PlushTheme.ink2)
            }
            .buttonStyle(PlushCircleIconButtonStyle(diameter: 20, variant: .secondary))
            .padding(.leading, 4)
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(PlushTheme.surfaceElevated)
                .plushSoftShadow(elevated: true)
        )
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

// MARK: - Plush Calendar Card (sidebar mini month calendar with gliding selection)

struct PlushMiniCalendar: View {
    let availableDays: Set<String>
    @Binding var selectedDay: String?
    let onSelectDay: (String) -> Void

    @State private var displayedMonth: Date
    @State private var slideDirection: CGFloat = 1
    @Namespace private var selectionNamespace

    private let calendar = Calendar.current
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    init(
        availableDays: Set<String>,
        selectedDay: Binding<String?>,
        onSelectDay: @escaping (String) -> Void
    ) {
        self.availableDays = availableDays
        self._selectedDay = selectedDay
        self.onSelectDay = onSelectDay

        let initialDate = selectedDay.wrappedValue.flatMap(TimelineFormatters.parseDay) ?? Date()
        let comps = Calendar.current.dateComponents([.year, .month], from: initialDate)
        self._displayedMonth = State(initialValue: Calendar.current.date(from: comps) ?? Date())
    }

    var body: some View {
        VStack(spacing: 10) {
            // Header: Month Title + Round Nav Arrows
            HStack {
                Text(monthTitle)
                    .font(PlushTheme.rounded(14, weight: .semibold))
                    .foregroundStyle(PlushTheme.ink)
                    .contentTransition(.opacity)

                Spacer()

                HStack(spacing: 5) {
                    Button {
                        shiftMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(PlushCircleIconButtonStyle(diameter: 24, variant: .secondary))
                    .help("上个月")

                    Button {
                        shiftMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(PlushCircleIconButtonStyle(diameter: 24, variant: .secondary))
                    .help("下个月")
                }
            }

            // Weekday Header
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                ForEach(weekdays, id: \.self) { label in
                    Text(label)
                        .font(PlushTheme.rounded(10.5, weight: .medium))
                        .foregroundStyle(PlushTheme.ink3)
                        .frame(height: 18)
                }

                ForEach(daysInGrid(), id: \.key) { cell in
                    if let date = cell.date {
                        let dayKey = TimelineFormatters.formatDayKey(date)
                        let hasRecords = availableDays.contains(dayKey)
                        let isSelected = selectedDay == dayKey
                        let isToday = calendar.isDateInToday(date)

                        Button {
                            if hasRecords {
                                withAnimation(PlushTheme.spring) {
                                    onSelectDay(dayKey)
                                }
                            }
                        } label: {
                            ZStack {
                                if isSelected {
                                    Circle()
                                        .fill(PlushTheme.selectGradient)
                                        .matchedGeometryEffect(id: "calendar-day-pill", in: selectionNamespace)
                                        .shadow(color: PlushTheme.selectA.opacity(0.28), radius: 5, x: 0, y: 2)
                                } else if isToday {
                                    Circle()
                                        .fill(PlushTheme.fill)
                                }

                                VStack(spacing: 1) {
                                    Text("\(calendar.component(.day, from: date))")
                                        .font(PlushTheme.rounded(11.5, weight: isSelected || hasRecords ? .semibold : .regular).monospacedDigit())
                                        .foregroundStyle(
                                            isSelected
                                            ? PlushTheme.onSelect
                                            : (hasRecords ? PlushTheme.ink : PlushTheme.ink3.opacity(0.65))
                                        )

                                    Circle()
                                        .fill(isSelected ? PlushTheme.onSelect.opacity(0.65) : PlushTheme.selectA)
                                        .frame(width: 3.5, height: 3.5)
                                        .opacity(hasRecords ? 1 : 0)
                                }
                            }
                            .frame(height: 28)
                            .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasRecords)
                    } else {
                        Color.clear
                            .frame(height: 28)
                    }
                }
            }
            .id(displayedMonth)
            .transition(
                .asymmetric(
                    insertion: .move(edge: slideDirection > 0 ? .trailing : .leading).combined(with: .opacity),
                    removal: .opacity
                )
            )
        }
        .padding(12)
        .plushCardSurface(cornerRadius: PlushTheme.Radius.card, background: PlushTheme.surface)
        .onChange(of: selectedDay) { newDay in
            guard let newDay, let parsed = TimelineFormatters.parseDay(newDay) else { return }
            let comps = calendar.dateComponents([.year, .month], from: parsed)
            if let targetMonth = calendar.date(from: comps), targetMonth != displayedMonth {
                slideDirection = targetMonth > displayedMonth ? 1 : -1
                withAnimation(PlushTheme.softSpring) {
                    displayedMonth = targetMonth
                }
            }
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy 年 M 月"
        return formatter.string(from: displayedMonth)
    }

    private func shiftMonth(by delta: Int) {
        slideDirection = delta > 0 ? 1 : -1
        if let next = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            withAnimation(PlushTheme.softSpring) {
                displayedMonth = next
            }
        }
    }

    private struct GridCell {
        let key: String
        let date: Date?
    }

    private func daysInGrid() -> [GridCell] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start) // 1 = Sunday
        let leadingEmpty = firstWeekday - 1

        var result: [GridCell] = []
        for idx in 0 ..< leadingEmpty {
            result.append(GridCell(key: "empty-\(idx)", date: nil))
        }

        for dayOffset in 0 ..< dayRange.count {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: monthInterval.start) {
                result.append(GridCell(key: TimelineFormatters.formatDayKey(date), date: date))
            }
        }
        return result
    }
}
