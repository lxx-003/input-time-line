import SwiftUI

struct InsightsDashboardView: View {
    @EnvironmentObject private var model: AppModel
    let insights: DailyInsights

    @State private var isCustomPopoverPresented = false
    @Namespace private var rangePillNamespace

    var body: some View {
        PlushScrollView {
            VStack(spacing: 12) {
                summaryHeaderCard
                ActivityTimelineCard(insights: insights) { selectedDay in
                    withAnimation(PlushTheme.spring) {
                        model.selectDay(selectedDay)
                    }
                }
                KeyboardHeatmapCard(insights: insights)
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 26)
        }
    }

    private var summaryHeaderCard: some View {
        let header = TimelineFormatters.insightsHeaderDisplay(insights.range)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(header.title)
                            .font(PlushTheme.rounded(20, weight: .semibold))
                            .foregroundStyle(PlushTheme.ink)

                        if let tag = header.subtitleTag {
                            Text(tag)
                                .font(PlushTheme.rounded(11.5, weight: .semibold))
                                .foregroundStyle(PlushTheme.ink2)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(PlushTheme.fill))
                        }
                    }

                    Text("统计口径：按每分钟内发生过键盘输入或剪贴板操作计为活跃分钟")
                        .font(PlushTheme.rounded(11.5, weight: .medium))
                        .foregroundStyle(PlushTheme.ink3)
                }

                Spacer(minLength: 8)

                rangePresetBar
            }

            HStack(spacing: 8) {
                if insights.isMultiDay {
                    metricTile(
                        title: "累计活跃",
                        value: formatDuration(minutes: insights.totalActiveMinutes),
                        subtitle: insights.activeDaysCount > 0 ? "日均 \(formatDuration(minutes: insights.averageDailyMinutes))" : nil,
                        accent: PlushTheme.selectA
                    )

                    let busiestTitle = insights.busiestDay?.shortLabel ?? "—"
                    let busiestSub = insights.busiestDay.map { formatDuration(minutes: $0.totalMinutes) }
                    metricTile(
                        title: "最忙一天",
                        value: busiestTitle,
                        subtitle: busiestSub,
                        accent: PlushTheme.kindKeyboard
                    )
                } else {
                    let peakLabel: String = {
                        guard let peakHour = insights.peakHour else { return "—" }
                        return String(format: "%02d:00", peakHour)
                    }()

                    metricTile(
                        title: "活跃时长",
                        value: formatDuration(minutes: insights.totalActiveMinutes),
                        accent: PlushTheme.selectA
                    )
                    metricTile(
                        title: "峰值时段",
                        value: peakLabel,
                        subtitle: insights.peakHourMinutes > 0 ? "\(insights.peakHourMinutes) 分钟" : nil,
                        accent: PlushTheme.kindKeyboard
                    )
                }

                metricTile(
                    title: "记录片段",
                    value: "\(insights.totalEvents) 条",
                    subtitle: insights.totalCharactersTyped > 0 ? "\(insights.totalCharactersTyped) 字" : nil,
                    accent: PlushTheme.kindPaste
                )

                let keySubtitle: String? = {
                    if !insights.hasKeyHeatmapData { return "暂无记录" }
                    if insights.isMultiDay && insights.daysWithKeyDataCount < insights.totalDaysInRange {
                        return "含 \(insights.daysWithKeyDataCount) 天"
                    }
                    return "已去连发"
                }()

                metricTile(
                    title: "物理按键",
                    value: insights.hasKeyHeatmapData ? "\(insights.totalKeyPresses) 次" : "—",
                    subtitle: keySubtitle,
                    accent: PlushTheme.kindCopy
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .plushCardSurface(cornerRadius: PlushTheme.Radius.card, background: PlushTheme.surface)
    }

    private var rangePresetBar: some View {
        let activePreset = model.insightsRange.preset

        return HStack(spacing: 3) {
            ForEach(InsightsRangePreset.allCases) { preset in
                let isSelected = activePreset == preset

                Button {
                    if preset == .custom {
                        isCustomPopoverPresented = true
                    } else {
                        withAnimation(PlushTheme.spring) {
                            model.setInsightsPreset(preset)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if preset == .custom {
                            Image(systemName: "calendar")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(isSelected ? PlushTheme.selectA : PlushTheme.ink3)
                        }
                        Text(presetLabel(preset))
                            .font(PlushTheme.rounded(11.5, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? PlushTheme.ink : PlushTheme.ink2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(PlushTheme.surfaceElevated)
                                .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
                                .matchedGeometryEffect(id: "insights-range-pill", in: rangePillNamespace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .popover(
                    isPresented: preset == .custom ? $isCustomPopoverPresented : .constant(false),
                    arrowEdge: .bottom
                ) {
                    CustomRangePickerPopover(
                        availableDays: model.availableDaySet,
                        initialRange: model.insightsRange,
                        onApply: { newRange in
                            withAnimation(PlushTheme.spring) {
                                model.setInsightsRange(newRange)
                            }
                        },
                        onDismiss: {
                            isCustomPopoverPresented = false
                        }
                    )
                }
            }
        }
        .animation(PlushTheme.spring, value: activePreset)
        .padding(3.5)
        .background(
            Capsule()
                .fill(PlushTheme.fillStrong)
        )
    }

    private func presetLabel(_ preset: InsightsRangePreset) -> String {
        switch preset {
        case .last7Days: return "近 7 天"
        default: return preset.rawValue
        }
    }

    private func metricTile(
        title: String,
        value: String,
        subtitle: String? = nil,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(PlushTheme.rounded(11, weight: .semibold))
                    .foregroundStyle(PlushTheme.ink2)
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(PlushTheme.rounded(15.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(PlushTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .plushNumericTransition()

                if let subtitle {
                    Text(subtitle)
                        .font(PlushTheme.rounded(10.5, weight: .medium).monospacedDigit())
                        .foregroundStyle(PlushTheme.ink3)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: PlushTheme.Radius.row, style: .continuous)
                .fill(PlushTheme.fill)
        )
    }

    private func formatDuration(minutes: Int) -> String {
        guard minutes > 0 else { return "0 分钟" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours) 小时"
        }
        return "\(mins) 分钟"
    }
}
