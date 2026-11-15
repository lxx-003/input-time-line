import SwiftUI

struct ActivityTimelineCard: View {
    let insights: DailyInsights
    var onSelectDay: ((String) -> Void)? = nil

    @State private var hoveredHour: Int?
    @State private var hoveredDayDate: String?
    @State private var hoveredLegendID: String?

    private var hoveredHourStat: HourlyActivityStat? {
        guard !insights.isMultiDay, let hoveredHour, (0..<24).contains(hoveredHour) else { return nil }
        return insights.hourlyStats[hoveredHour]
    }

    private var hoveredDayStat: DailyActivityStat? {
        guard insights.isMultiDay, let hoveredDayDate else { return nil }
        return insights.dailyStats.first { $0.date == hoveredDayDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Card Header
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("活跃时间线")
                            .font(PlushTheme.rounded(15.5, weight: .semibold))
                            .foregroundStyle(PlushTheme.ink)

                        Text(insights.isMultiDay ? "每日各应用活跃趋势 · 点击柱条可下钻单日" : "24 小时各应用活跃分布")
                            .font(PlushTheme.rounded(11, weight: .medium))
                            .foregroundStyle(PlushTheme.ink3)
                    }

                    Group {
                        if let stat = hoveredHourStat {
                            hoveredHourSummaryRow(stat: stat)
                        } else if let dayStat = hoveredDayStat {
                            hoveredDaySummaryRow(stat: dayStat)
                        } else {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(formatDuration(minutes: insights.totalActiveMinutes))
                                    .font(PlushTheme.rounded(22, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(PlushTheme.ink)

                                if insights.isMultiDay && insights.activeDaysCount > 0 {
                                    Text("日均 \(formatCompactDuration(minutes: insights.averageDailyMinutes)) · 活跃 \(insights.activeDaysCount)/\(insights.totalDaysInRange) 天")
                                        .font(PlushTheme.rounded(12, weight: .medium).monospacedDigit())
                                        .foregroundStyle(PlushTheme.ink2)
                                }
                            }
                        }
                    }
                    .frame(height: 27, alignment: .leading)
                }

                Spacer()
            }

            // Chart Area (Canvas-backed for smooth 120fps scrolling even on 100+ day ranges)
            if insights.totalActiveMinutes == 0 {
                emptyChartPlaceholder
            } else if insights.isMultiDay {
                dailyBarChart
                    .frame(height: 178)
            } else {
                hourlyBarChart
                    .frame(height: 174)
            }

            // Legend
            if !insights.appSummaries.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(insights.appSummaries) { item in
                            legendChip(item: item)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .padding(18)
        .plushCardSurface(cornerRadius: PlushTheme.Radius.card, background: PlushTheme.surface)
    }

    @ViewBuilder
    private func hoveredHourSummaryRow(stat: HourlyActivityStat) -> some View {
        let hourText = String(format: "%02d:00 – %02d:00", stat.hour, (stat.hour + 1) % 24 == 0 ? 24 : stat.hour + 1)
        hoveredSummaryRow(title: hourText, minutes: stat.totalMinutes, slices: stat.appSlices)
    }

    @ViewBuilder
    private func hoveredDaySummaryRow(stat: DailyActivityStat) -> some View {
        hoveredSummaryRow(title: stat.fullLabel, minutes: stat.totalMinutes, slices: stat.appSlices)
    }

    private func hoveredSummaryRow(title: String, minutes: Int, slices: [ActivityBucketSlice]) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(PlushTheme.rounded(15, weight: .semibold).monospacedDigit())
                .foregroundStyle(PlushTheme.ink)

            Text("·")
                .foregroundStyle(PlushTheme.ink3)

            Text(formatDuration(minutes: minutes))
                .font(PlushTheme.rounded(15, weight: .semibold).monospacedDigit())
                .foregroundStyle(PlushTheme.selectA)

            if !slices.isEmpty {
                HStack(spacing: 6) {
                    ForEach(slices.prefix(3)) { slice in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(sliceColor(colorIndex: slice.colorIndex))
                                .frame(width: 6, height: 6)
                            Text("\(slice.label) \(formatCompactDuration(minutes: slice.minutes))")
                                .font(PlushTheme.rounded(11, weight: .medium))
                                .foregroundStyle(PlushTheme.ink2)
                        }
                    }
                }
                .padding(.leading, 2)
            }
        }
    }

    private var emptyChartPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 22))
                .foregroundStyle(PlushTheme.ink3)
            Text(insights.isMultiDay ? "该时段内暂无输入或剪贴板活跃记录" : "当天暂无输入或剪贴板活跃记录")
                .font(PlushTheme.rounded(12.5, weight: .medium))
                .foregroundStyle(PlushTheme.ink2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .background(
            RoundedRectangle(cornerRadius: PlushTheme.Radius.row, style: .continuous)
                .fill(PlushTheme.fill.opacity(0.55))
        )
    }

    // MARK: - Single-Day 24-Hour Stacked Bar Chart (Canvas)

    private var hourlyBarChart: some View {
        let yAxisWidth: CGFloat = 46
        let xLabelHeight: CGFloat = 22

        return GeometryReader { proxy in
            let plotWidth = max(120, proxy.size.width - yAxisWidth)
            let plotHeight = max(80, proxy.size.height - xLabelHeight)
            let columnWidth = plotWidth / 24.0
            let barWidth = min(14, max(6, columnWidth * 0.56))

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Canvas { context, size in
                        drawHorizontalGrid(in: &context, width: size.width, height: size.height)

                        for hourMark in [0, 6, 12, 18, 24] {
                            let xPos = CGFloat(hourMark) * columnWidth
                            var line = Path()
                            line.move(to: CGPoint(x: xPos, y: 0))
                            line.addLine(to: CGPoint(x: xPos, y: size.height))
                            context.stroke(
                                line,
                                with: .color(PlushTheme.line),
                                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                            )
                        }

                        for stat in insights.hourlyStats {
                            let capped = min(60, stat.totalMinutes)
                            let barHeight = capped > 0 ? max(5, CGFloat(capped) / 60.0 * size.height) : 0
                            drawStackedBar(
                                in: &context,
                                index: stat.hour,
                                columnWidth: columnWidth,
                                barWidth: barWidth,
                                plotHeight: size.height,
                                barHeight: barHeight,
                                totalMinutes: stat.totalMinutes,
                                slices: stat.appSlices,
                                isHovered: hoveredHour == stat.hour
                            )
                        }
                    }
                    .frame(width: plotWidth, height: plotHeight)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let idx = max(0, min(23, Int(location.x / columnWidth)))
                            if hoveredHour != idx {
                                hoveredHour = idx
                            }
                        case .ended:
                            if hoveredHour != nil {
                                hoveredHour = nil
                            }
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("1 小时")
                        Spacer()
                        Text("30 分")
                        Spacer()
                        Text("0")
                    }
                    .font(PlushTheme.rounded(10.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(PlushTheme.ink3)
                    .padding(.leading, 8)
                    .frame(width: yAxisWidth, height: plotHeight, alignment: .leading)
                }

                ZStack(alignment: .leading) {
                    ForEach([0, 6, 12, 18], id: \.self) { hourMark in
                        Text("\(hourMark) 时")
                            .font(PlushTheme.rounded(10.5, weight: .medium).monospacedDigit())
                            .foregroundStyle(PlushTheme.ink3)
                            .offset(x: CGFloat(hourMark) * columnWidth + 3)
                    }
                }
                .frame(width: plotWidth, height: xLabelHeight, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Multi-Day Daily Trend Stacked Bar Chart (Canvas)

    private var dailyBarChart: some View {
        let stats = insights.dailyStats
        let dayCount = max(1, stats.count)
        let yAxisWidth: CGFloat = 52
        let xLabelHeight: CGFloat = 24
        let yMaxMinutes = niceDailyCeilingMinutes(maxMinutes: stats.map(\.totalMinutes).max() ?? 0)

        return GeometryReader { proxy in
            let plotWidth = max(120, proxy.size.width - yAxisWidth)
            let plotHeight = max(80, proxy.size.height - xLabelHeight)
            let columnWidth = plotWidth / CGFloat(dayCount)
            let barWidth = min(30, max(3.5, columnWidth * 0.52))

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Canvas { context, size in
                        drawHorizontalGrid(in: &context, width: size.width, height: size.height)

                        if insights.averageDailyMinutes > 0 && insights.averageDailyMinutes < yMaxMinutes {
                            let avgRatio = CGFloat(insights.averageDailyMinutes) / CGFloat(yMaxMinutes)
                            let yPos = size.height * (1.0 - avgRatio)
                            var avgLine = Path()
                            avgLine.move(to: CGPoint(x: 0, y: yPos))
                            avgLine.addLine(to: CGPoint(x: size.width, y: yPos))
                            context.stroke(
                                avgLine,
                                with: .color(PlushTheme.selectA.opacity(0.45)),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                            )
                        }

                        for (index, stat) in stats.enumerated() {
                            let barHeight = stat.totalMinutes > 0
                                ? max(5, CGFloat(stat.totalMinutes) / CGFloat(max(1, yMaxMinutes)) * size.height)
                                : 0
                            drawStackedBar(
                                in: &context,
                                index: index,
                                columnWidth: columnWidth,
                                barWidth: barWidth,
                                plotHeight: size.height,
                                barHeight: barHeight,
                                totalMinutes: stat.totalMinutes,
                                slices: stat.appSlices,
                                isHovered: hoveredDayDate == stat.date
                            )
                        }
                    }
                    .frame(width: plotWidth, height: plotHeight)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let idx = max(0, min(dayCount - 1, Int(location.x / columnWidth)))
                            let targetDate = stats[idx].date
                            if hoveredDayDate != targetDate {
                                hoveredDayDate = targetDate
                            }
                        case .ended:
                            if hoveredDayDate != nil {
                                hoveredDayDate = nil
                            }
                        }
                    }
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                let idx = max(0, min(dayCount - 1, Int(value.location.x / columnWidth)))
                                onSelectDay?(stats[idx].date)
                            }
                    )

                    VStack(alignment: .leading) {
                        Text(formatAxisDuration(minutes: yMaxMinutes))
                        Spacer()
                        Text(formatAxisDuration(minutes: yMaxMinutes / 2))
                        Spacer()
                        Text("0")
                    }
                    .font(PlushTheme.rounded(10.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(PlushTheme.ink3)
                    .padding(.leading, 8)
                    .frame(width: yAxisWidth, height: plotHeight, alignment: .leading)
                }

                // Bottom X-axis day labels (collision-free spacing)
                ZStack(alignment: .leading) {
                    let visibleIndices = visibleDayAxisIndices(total: dayCount, plotWidth: plotWidth)
                    ForEach(visibleIndices, id: \.self) { index in
                        let stat = stats[index]
                        let centerX = (CGFloat(index) + 0.5) * columnWidth
                        let anchorX = min(max(18, centerX), plotWidth - 18)
                        Text(stat.shortLabel)
                            .font(PlushTheme.rounded(10.5, weight: stat.totalMinutes > 0 ? .medium : .regular).monospacedDigit())
                            .foregroundStyle(hoveredDayDate == stat.date ? PlushTheme.ink : PlushTheme.ink3)
                            .lineLimit(1)
                            .fixedSize()
                            .position(x: anchorX, y: xLabelHeight / 2)
                    }
                }
                .frame(width: plotWidth, height: xLabelHeight, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Canvas Drawing Helpers

    private func drawHorizontalGrid(in context: inout GraphicsContext, width: CGFloat, height: CGFloat) {
        for (idx, y) in [CGFloat(0.5), height * 0.5, height - 0.5].enumerated() {
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: width, y: y))
            let style = idx < 2 ? StrokeStyle(lineWidth: 1, dash: [3, 3]) : StrokeStyle(lineWidth: 1)
            context.stroke(line, with: .color(PlushTheme.line), style: style)
        }
    }

    private func drawStackedBar(
        in context: inout GraphicsContext,
        index: Int,
        columnWidth: CGFloat,
        barWidth: CGFloat,
        plotHeight: CGFloat,
        barHeight: CGFloat,
        totalMinutes: Int,
        slices: [ActivityBucketSlice],
        isHovered: Bool
    ) {
        let colX = CGFloat(index) * columnWidth

        if isHovered {
            let hoverWidth = max(barWidth + 6, min(columnWidth, barWidth + 10))
            let hoverRect = CGRect(
                x: colX + (columnWidth - hoverWidth) / 2,
                y: 0,
                width: hoverWidth,
                height: plotHeight
            )
            let hoverPath = Path(roundedRect: hoverRect, cornerRadius: 6, style: .continuous)
            context.fill(hoverPath, with: .color(PlushTheme.fill.opacity(0.85)))
        }

        guard barHeight > 0, !slices.isEmpty else { return }

        let activeBarWidth = isHovered ? barWidth * 1.1 : barWidth
        let barX = colX + (columnWidth - activeBarWidth) / 2
        let barRect = CGRect(x: barX, y: plotHeight - barHeight, width: activeBarWidth, height: barHeight)
        let cornerRadius = min(5, activeBarWidth / 2)
        let clipPath = Path(roundedRect: barRect, cornerRadius: cornerRadius, style: .continuous)

        context.drawLayer { layer in
            layer.clip(to: clipPath)

            // Draw from top down (slices in original order: index 0 at bottom, rest stacked above)
            let gap: CGFloat = slices.count > 1 ? 1.0 : 0.0
            let totalGap = gap * CGFloat(max(0, slices.count - 1))
            let usableHeight = max(1, barHeight - totalGap)
            var currentBottom = plotHeight

            for slice in slices {
                let rawH = usableHeight * CGFloat(slice.minutes) / CGFloat(max(1, totalMinutes))
                let sliceH = max(1.5, rawH)
                let sliceY = currentBottom - sliceH
                let sliceRect = CGRect(x: barX, y: sliceY, width: activeBarWidth, height: sliceH)
                let isDimmed = hoveredLegendID != nil && hoveredLegendID != sliceKey(for: slice)
                let color = sliceColor(colorIndex: slice.colorIndex).opacity(isDimmed ? 0.22 : 1.0)
                layer.fill(Path(sliceRect), with: .color(color))
                currentBottom = sliceY - gap
            }
        }
    }

    private func visibleDayAxisIndices(total: Int, plotWidth: CGFloat) -> [Int] {
        guard total > 1 else { return total == 1 ? [0] : [] }
        let maxLabels = max(2, min(9, Int(plotWidth / 64)))
        if total <= maxLabels {
            return Array(0..<total)
        }
        let step = max(2, Int(ceil(Double(total - 1) / Double(maxLabels - 1))))
        var indices: [Int] = [0]
        var cursor = step
        let minTrailingGap = max(2, step / 2)
        while cursor < total - 1 {
            if (total - 1 - cursor) >= minTrailingGap {
                indices.append(cursor)
            }
            cursor += step
        }
        indices.append(total - 1)
        return indices
    }

    private func niceDailyCeilingMinutes(maxMinutes: Int) -> Int {
        switch maxMinutes {
        case ...60: return 60
        case ...120: return 120
        case ...240: return 240
        case ...360: return 360
        case ...480: return 480
        case ...720: return 720
        default:
            let twoHourBlocks = Int(ceil(Double(maxMinutes) / 120.0))
            return max(720, twoHourBlocks * 120)
        }
    }

    private func formatAxisDuration(minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m == 0 ? "\(h) 小时" : "\(h)h\(m)m"
        }
        return "\(minutes) 分"
    }

    private func legendChip(item: AppActivitySummary) -> some View {
        let isHighlighted = hoveredLegendID == item.id
        let color = sliceColor(colorIndex: item.colorIndex)

        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            if item.colorIndex != -1, let icon = AppIconProvider.shared.icon(for: item.name) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 13, height: 13)
            }

            Text(item.name)
                .font(PlushTheme.rounded(11.5, weight: .semibold))
                .foregroundStyle(PlushTheme.ink)
                .lineLimit(1)

            Text(formatCompactDuration(minutes: item.minutes))
                .font(PlushTheme.rounded(11, weight: .semibold).monospacedDigit())
                .foregroundStyle(PlushTheme.ink2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(isHighlighted ? PlushTheme.fillStrong : PlushTheme.fill)
        )
        .contentShape(Capsule())
        .onHover { hovering in
            withAnimation(PlushTheme.fastFade) {
                hoveredLegendID = hovering ? item.id : (hoveredLegendID == item.id ? nil : hoveredLegendID)
            }
        }
    }

    private func sliceKey(for slice: ActivityBucketSlice) -> String {
        if slice.colorIndex == -1 {
            return "__other__"
        }
        return slice.label
    }

    private func sliceColor(colorIndex: Int) -> Color {
        switch colorIndex {
        case 0: return PlushTheme.kindKeyboard
        case 1: return Color(red: 0.055, green: 0.647, blue: 0.914) // Sky Teal
        case 2: return PlushTheme.kindPaste
        case 3: return PlushTheme.kindCopy
        case 4: return PlushTheme.pink
        default: return PlushTheme.ink3.opacity(0.55)
        }
    }

    private func formatDuration(minutes: Int) -> String {
        guard minutes > 0 else { return "0 分钟" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours) 小时 \(mins) 分钟"
        } else if hours > 0 {
            return "\(hours) 小时"
        }
        return "\(mins) 分钟"
    }

    private func formatCompactDuration(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h\(mins)m" : "\(hours)h"
        }
        return "\(mins)m"
    }
}
