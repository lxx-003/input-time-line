import SwiftUI

struct TimelineSidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            // Top bar inside sidebar (leaves clean room for macOS traffic lights)
            HStack(spacing: 8) {
                Text("时间档案")
                    .font(PlushTheme.rounded(15, weight: .semibold))
                    .foregroundStyle(PlushTheme.ink)

                Spacer()

                Button {
                    withAnimation(PlushTheme.softSpring) {
                        model.isCalendarExpanded.toggle()
                    }
                } label: {
                    Image(systemName: model.isCalendarExpanded ? "calendar.badge.minus" : "calendar")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(PlushCircleIconButtonStyle(
                    diameter: 28,
                    variant: model.isCalendarExpanded ? .surface : .secondary
                ))
                .help(model.isCalendarExpanded ? "收起月历" : "展开月历")
            }
            .padding(.horizontal, 14)
            .padding(.top, 36)

            // Collapsible Plush Calendar
            if model.isCalendarExpanded {
                PlushMiniCalendar(
                    availableDays: model.availableDaySet,
                    selectedDay: Binding(
                        get: { model.selectedDay },
                        set: { day in
                            if let day { model.selectDay(day) }
                        }
                    ),
                    highlightedRangeDays: model.sidebarHighlightedRangeDays,
                    onSelectDay: { day in
                        model.selectDay(day)
                    }
                )
                .padding(.horizontal, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Day list
            if model.groupedDaySections.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 24))
                        .foregroundStyle(PlushTheme.ink3)
                    Text("暂无历史日期")
                        .font(PlushTheme.rounded(13, weight: .semibold))
                        .foregroundStyle(PlushTheme.ink2)
                    Text("开启记录后将按天归档")
                        .font(PlushTheme.rounded(11.5))
                        .foregroundStyle(PlushTheme.ink3)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                PlushScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(model.groupedDaySections) { section in
                            Section {
                                ForEach(section.days) { entry in
                                    let isRangeMode = model.isInsightsMultiDayMode
                                    let isInRange = model.sidebarHighlightedRangeDays.contains(entry.id)
                                    SidebarDayRow(
                                        entry: entry,
                                        isSelected: !isRangeMode && model.selectedDay == entry.id,
                                        isInRange: isInRange
                                    ) {
                                        model.selectDay(entry.id)
                                    }
                                }
                            } header: {
                                Text(section.title)
                                    .font(PlushTheme.rounded(11, weight: .semibold))
                                    .foregroundStyle(PlushTheme.ink3)
                                    .padding(.horizontal, 10)
                                    .padding(.top, section.id == model.groupedDaySections.first?.id ? 0 : 10)
                                    .padding(.bottom, 2)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
            }

            // Floating Status Control Card
            sidebarStatusCard
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(PlushTheme.panel.ignoresSafeArea(.container, edges: .top))
    }

    private var sidebarStatusCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(statusDotColor.opacity(0.22))
                        .frame(width: 18, height: 18)

                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 8, height: 8)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(footerStatusTitle)
                        .font(PlushTheme.rounded(12.5, weight: .semibold))
                        .foregroundStyle(PlushTheme.ink)
                        .lineLimit(1)

                    Text(footerStatusSubtitle)
                        .font(PlushTheme.rounded(10.5, weight: .medium))
                        .foregroundStyle(PlushTheme.ink2)
                        .lineLimit(1)
                }

                Spacer()

                PlushSwitch(
                    isOn: Binding(
                        get: { model.isRecording },
                        set: { model.toggleRecording($0) }
                    ),
                    size: .small
                )
            }

            HStack(spacing: 6) {
                if model.isRecording {
                    Menu {
                        Button("暂停 15 分钟") { model.pauseTemporarily(minutes: 15) }
                        Button("暂停 30 分钟") { model.pauseTemporarily(minutes: 30) }
                        Button("暂停 1 小时") { model.pauseTemporarily(minutes: 60) }
                        Divider()
                        Button("打开设置...") { model.openSettings() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.system(size: 10))
                            Text("限时暂停")
                                .font(PlushTheme.rounded(11, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8.5, weight: .bold))
                        }
                        .foregroundStyle(PlushTheme.ink2)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(PlushTheme.fill))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                } else {
                    Text("偏好设置")
                        .font(PlushTheme.rounded(11, weight: .medium))
                        .foregroundStyle(PlushTheme.ink3)
                        .padding(.leading, 2)
                }

                Spacer()

                let isSettingsActive = model.activeMainTab == .settings
                Button {
                    model.toggleSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSettingsActive ? PlushTheme.onAccent : PlushTheme.ink2)
                }
                .buttonStyle(PlushCircleIconButtonStyle(
                    diameter: 24,
                    variant: isSettingsActive ? .primary : .secondary
                ))
                .help(isSettingsActive ? "返回上一视图" : "打开设置 (⌘,)")
            }
        }
        .padding(12)
        .plushCardSurface(cornerRadius: PlushTheme.Radius.card, background: PlushTheme.surface)
    }

    private var statusDotColor: Color {
        if !model.permissionGranted || model.tapCreationFailed {
            return PlushTheme.warning
        }
        return model.isRecording ? PlushTheme.success : PlushTheme.ink3
    }

    private var footerStatusTitle: String {
        if !model.permissionGranted || model.tapCreationFailed {
            return "监控未就绪"
        }
        return model.isRecording ? "正在采集中" : "已暂停采集"
    }

    private var footerStatusSubtitle: String {
        if !model.permissionGranted || model.tapCreationFailed {
            return "需要系统输入监控权限"
        }
        if let resumeDate = model.pauseResumeDate, !model.isRecording {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "将于 \(formatter.string(from: resumeDate)) 自动恢复"
        }
        return model.isRecording ? "键盘与剪贴板实时归档" : "开启开关恢复采集"
    }
}

// MARK: - Isolated Sidebar Day Row (avoids re-rendering parent on hover)

private struct SidebarDayRow: View {
    let entry: TimelineFormatters.DayEntry
    let isSelected: Bool
    let isInRange: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(
                        isSelected
                        ? AnyShapeStyle(PlushTheme.selectGradient)
                        : (isInRange ? AnyShapeStyle(PlushTheme.selectA) : AnyShapeStyle(Color.clear))
                    )
                    .frame(width: 7, height: 7)

                Text(entry.primary)
                    .font(PlushTheme.rounded(12.5, weight: isSelected || isInRange ? .semibold : .medium).monospacedDigit())
                    .foregroundStyle(isSelected || isInRange ? PlushTheme.ink : PlushTheme.ink2)

                Spacer()

                if let badge = entry.badge {
                    Text(badge)
                        .font(PlushTheme.rounded(10.5, weight: .semibold))
                        .foregroundStyle(isSelected ? PlushTheme.onSelect : PlushTheme.ink2)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? AnyShapeStyle(PlushTheme.selectGradient) : AnyShapeStyle(PlushTheme.fill))
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: PlushTheme.Radius.item, style: .continuous)
                    .fill(
                        isSelected
                        ? PlushTheme.surfaceElevated
                        : (isInRange ? PlushTheme.selectPlate : (isHovered ? PlushTheme.fillStrong.opacity(0.65) : .clear))
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: PlushTheme.Radius.item, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if isHovered != hovering {
                isHovered = hovering
            }
        }
    }
}
