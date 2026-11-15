import SwiftUI

struct CustomRangePickerPopover: View {
    let availableDays: Set<String>
    let initialRange: InsightsDateRange
    let onApply: (InsightsDateRange) -> Void
    let onDismiss: () -> Void

    @State private var displayedMonth: Date
    @State private var draftStart: Date
    @State private var draftEnd: Date?
    @State private var hoveredDate: Date?

    private let calendar = Calendar.current
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    init(
        availableDays: Set<String>,
        initialRange: InsightsDateRange,
        onApply: @escaping (InsightsDateRange) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.availableDays = availableDays
        self.initialRange = initialRange
        self.onApply = onApply
        self.onDismiss = onDismiss

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let parsedStart = TimelineFormatters.parseDay(initialRange.startDay).map { cal.startOfDay(for: $0) } ?? today
        let parsedEnd = TimelineFormatters.parseDay(initialRange.endDay).map { cal.startOfDay(for: $0) } ?? parsedStart
        let monthAnchor = parsedEnd
        let monthComps = cal.dateComponents([.year, .month], from: monthAnchor)

        self._draftStart = State(initialValue: min(parsedStart, parsedEnd))
        self._draftEnd = State(initialValue: max(parsedStart, parsedEnd))
        self._displayedMonth = State(initialValue: cal.date(from: monthComps) ?? today)
    }

    private var todayStart: Date {
        calendar.startOfDay(for: Date())
    }

    private var effectiveRange: (start: Date, end: Date) {
        if let end = draftEnd {
            return (min(draftStart, end), max(draftStart, end))
        }
        if let hovered = hoveredDate {
            return (min(draftStart, hovered), max(draftStart, hovered))
        }
        return (draftStart, draftStart)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Quick Presets Header
            HStack(spacing: 6) {
                Text("快捷区间")
                    .font(PlushTheme.rounded(11, weight: .semibold))
                    .foregroundStyle(PlushTheme.ink3)

                Spacer()

                quickPresetButton("近 14 天") {
                    applyQuickRange(daysBack: 13)
                }
                quickPresetButton("近 30 天") {
                    applyQuickRange(daysBack: 29)
                }
                quickPresetButton("本月") {
                    let comps = calendar.dateComponents([.year, .month], from: todayStart)
                    if let monthStart = calendar.date(from: comps) {
                        draftStart = monthStart
                        draftEnd = todayStart
                        displayedMonth = monthStart
                    }
                }
            }

            // Month Navigation
            HStack {
                Text(monthTitle)
                    .font(PlushTheme.rounded(14, weight: .semibold))
                    .foregroundStyle(PlushTheme.ink)

                Spacer()

                HStack(spacing: 5) {
                    Button {
                        shiftMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(PlushCircleIconButtonStyle(diameter: 24, variant: .secondary))

                    Button {
                        shiftMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(PlushCircleIconButtonStyle(diameter: 24, variant: .secondary))
                }
            }

            // Calendar Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                ForEach(weekdays, id: \.self) { label in
                    Text(label)
                        .font(PlushTheme.rounded(10.5, weight: .medium))
                        .foregroundStyle(PlushTheme.ink3)
                        .frame(height: 18)
                }

                ForEach(daysInGrid(), id: \.key) { cell in
                    if let date = cell.date {
                        dayCell(date: date)
                    } else {
                        Color.clear.frame(height: 30)
                    }
                }
            }

            Divider()
                .overlay(PlushTheme.line)

            // Footer Summary & Actions
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rangeSummaryText)
                        .font(PlushTheme.rounded(11.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(PlushTheme.ink)

                    Text(draftEnd == nil ? "请点击结束日期" : "共 \(daySpanCount) 天")
                        .font(PlushTheme.rounded(10.5, weight: .medium))
                        .foregroundStyle(draftEnd == nil ? PlushTheme.selectA : PlushTheme.ink3)
                }

                Spacer()

                Button("取消") {
                    onDismiss()
                }
                .buttonStyle(PlushPillButtonStyle(variant: .secondary, size: .xs))

                Button("应用") {
                    let final = effectiveRange
                    let startKey = TimelineFormatters.formatDayKey(final.start)
                    let endKey = TimelineFormatters.formatDayKey(final.end)
                    onApply(InsightsDateRange(preset: .custom, startDay: startKey, endDay: endKey))
                    onDismiss()
                }
                .buttonStyle(PlushPillButtonStyle(variant: .primary, size: .xs))
            }
        }
        .padding(14)
        .frame(width: 288)
        .background(PlushTheme.surfaceElevated)
    }

    @ViewBuilder
    private func dayCell(date: Date) -> some View {
        let dayStart = calendar.startOfDay(for: date)
        let dayKey = TimelineFormatters.formatDayKey(dayStart)
        let hasRecords = availableDays.contains(dayKey)
        let isFuture = dayStart > todayStart
        let span = effectiveRange
        let isBoundary = dayStart == span.start || dayStart == span.end
        let isInside = dayStart > span.start && dayStart < span.end

        Button {
            guard !isFuture else { return }
            withAnimation(PlushTheme.fastFade) {
                if draftEnd != nil {
                    draftStart = dayStart
                    draftEnd = nil
                } else {
                    if dayStart < draftStart {
                        draftEnd = draftStart
                        draftStart = dayStart
                    } else {
                        draftEnd = dayStart
                    }
                }
            }
        } label: {
            ZStack {
                if isInside {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(PlushTheme.selectPlate)
                } else if isBoundary {
                    Circle()
                        .fill(PlushTheme.selectGradient)
                        .shadow(color: PlushTheme.selectA.opacity(0.24), radius: 4, x: 0, y: 1.5)
                }

                VStack(spacing: 1) {
                    Text("\(calendar.component(.day, from: dayStart))")
                        .font(PlushTheme.rounded(11.5, weight: isBoundary || isInside || hasRecords ? .semibold : .regular).monospacedDigit())
                        .foregroundStyle(
                            isFuture
                            ? PlushTheme.ink3.opacity(0.35)
                            : (isBoundary ? PlushTheme.onSelect : PlushTheme.ink)
                        )

                    Circle()
                        .fill(isBoundary ? PlushTheme.onSelect.opacity(0.65) : PlushTheme.selectA)
                        .frame(width: 3, height: 3)
                        .opacity(hasRecords && !isFuture ? 1 : 0)
                }
            }
            .frame(height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .onHover { hovering in
            if !isFuture {
                hoveredDate = hovering ? dayStart : (hoveredDate == dayStart ? nil : hoveredDate)
            }
        }
    }

    private func quickPresetButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(PlushTheme.fastFade) {
                action()
            }
        } label: {
            Text(title)
                .font(PlushTheme.rounded(10.5, weight: .semibold))
                .foregroundStyle(PlushTheme.ink2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(PlushTheme.fill))
        }
        .buttonStyle(.plain)
    }

    private func applyQuickRange(daysBack: Int) {
        let start = calendar.date(byAdding: .day, value: -daysBack, to: todayStart) ?? todayStart
        draftStart = start
        draftEnd = todayStart
        let comps = calendar.dateComponents([.year, .month], from: todayStart)
        if let m = calendar.date(from: comps) {
            displayedMonth = m
        }
    }

    private var daySpanCount: Int {
        let span = effectiveRange
        let diff = calendar.dateComponents([.day], from: span.start, to: span.end).day ?? 0
        return max(1, diff + 1)
    }

    private var rangeSummaryText: String {
        let span = effectiveRange
        let startStr = TimelineFormatters.shortMonthDay(TimelineFormatters.formatDayKey(span.start))
        let endStr = TimelineFormatters.shortMonthDay(TimelineFormatters.formatDayKey(span.end))
        return startStr == endStr ? startStr : "\(startStr) – \(endStr)"
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy 年 M 月"
        return formatter.string(from: displayedMonth)
    }

    private func shiftMonth(by delta: Int) {
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

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
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
