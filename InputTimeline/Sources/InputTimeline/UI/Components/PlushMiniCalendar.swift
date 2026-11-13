import SwiftUI

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
