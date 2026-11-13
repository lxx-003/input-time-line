import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 266)

            Rectangle()
                .fill(PlushTheme.line)
                .frame(width: 1)
                .ignoresSafeArea(.container, edges: .top)

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(PlushTheme.bg.ignoresSafeArea(.container, edges: .top))
        .background(WindowStyleConfigurator())
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.handleAppDidBecomeActive()
        }
        .sheet(item: $model.inspectedEntry) { entry in
            TimelineDetailSheet(entry: entry, searchQuery: model.searchText) { text in
                model.copyRawString(text)
            }
        }
        .overlay {
            // Keyboard shortcuts layer
            Group {
                Button("") { isSearchFocused = true }
                    .keyboardShortcut("f", modifiers: .command)
                Button("") { model.setKindFilter(.all) }
                    .keyboardShortcut("1", modifiers: .command)
                Button("") { model.setKindFilter(.keyboard) }
                    .keyboardShortcut("2", modifiers: .command)
                Button("") { model.setKindFilter(.copy) }
                    .keyboardShortcut("3", modifiers: .command)
                Button("") { model.setKindFilter(.paste) }
                    .keyboardShortcut("4", modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
            .allowsHitTesting(false)
        }
        .frame(minWidth: 940, minHeight: 620)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
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
            .padding(.top, 10)

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
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(model.groupedDaySections) { section in
                            Section {
                                ForEach(section.days) { entry in
                                    SidebarDayRow(
                                        entry: entry,
                                        isSelected: model.selectedDay == entry.id
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
                .thinOverlayScrollbar()
            }

            // Floating Status Control Card
            sidebarStatusCard
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
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

            if model.isRecording {
                HStack(spacing: 6) {
                    Menu {
                        Button("暂停 15 分钟") { model.pauseTemporarily(minutes: 15) }
                        Button("暂停 30 分钟") { model.pauseTemporarily(minutes: 30) }
                        Button("暂停 1 小时") { model.pauseTemporarily(minutes: 60) }
                        Divider()
                        Button("打开设置...") { SettingsNavigator.open() }
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

                    Spacer()

                    Button {
                        SettingsNavigator.open()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(PlushTheme.ink2)
                    }
                    .buttonStyle(PlushCircleIconButtonStyle(diameter: 24, variant: .secondary))
                    .help("打开设置 (⌘,)")
                }
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

    // MARK: - Detail Canvas

    private var detail: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Top Plush Control Bar (sits cleanly below transparent macOS titlebar safe area)
                topControlBar
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                    .padding(.bottom, 12)

                if (!model.permissionGranted || model.tapCreationFailed) && model.selectedTimeline != nil {
                    compactPermissionStrip
                        .padding(.horizontal, 22)
                        .padding(.bottom, 12)
                }

                if let timeline = model.selectedTimeline {
                    detailHeaderCard(timeline: timeline)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 12)

                    if timeline.items.isEmpty {
                        filteredEmptyState(dayTotalCount: timeline.dayTotalCount)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(timeline.items) { entry in
                                    TimelineCardView(
                                        entry: entry,
                                        searchQuery: model.searchText,
                                        activeAppFilter: model.selectedAppFilter,
                                        onCopy: { model.copyItemText(entry) },
                                        onInspect: { model.inspectFullText(entry) },
                                        onToggleAppFilter: { appName in
                                            withAnimation(PlushTheme.spring) {
                                                model.toggleAppFilter(appName)
                                            }
                                        }
                                    )
                                }

                                if timeline.hasMore {
                                    loadMoreRow(timeline: timeline)
                                }
                            }
                            .padding(.horizontal, 22)
                            .padding(.top, 4)
                            .padding(.bottom, 26)
                        }
                        .thinOverlayScrollbar()
                    }
                } else if !model.permissionGranted {
                    permissionOnboardingState
                } else {
                    noTimelineEmptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PlushTheme.bg.ignoresSafeArea(.container, edges: .top))

            // Global Plush Sonner Toast
            if let toast = model.activeToast {
                PlushToastBanner(toast: toast) {
                    model.dismissToast()
                }
                .padding(.trailing, 22)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.92)))
                .zIndex(50)
            }
        }
    }

    private var topControlBar: some View {
        let kindCounts = model.selectedTimeline?.kindCounts ?? [:]
        let dayTotal = model.selectedTimeline?.dayTotalCount
        let tabOptions: [PlushTabOption<TimelineKindFilter>] = [
            PlushTabOption(
                value: .all,
                title: "全部",
                count: dayTotal,
                dotColor: nil
            ),
            PlushTabOption(
                value: .keyboard,
                title: "键盘",
                count: dayTotal == nil ? nil : kindCounts[.keyboard, default: 0],
                dotColor: PlushTheme.kindKeyboard
            ),
            PlushTabOption(
                value: .copy,
                title: "复制",
                count: dayTotal == nil ? nil : kindCounts[.copy, default: 0],
                dotColor: PlushTheme.kindCopy
            ),
            PlushTabOption(
                value: .paste,
                title: "粘贴",
                count: dayTotal == nil ? nil : kindCounts[.paste, default: 0],
                dotColor: PlushTheme.kindPaste
            )
        ]

        return HStack(spacing: 12) {
            PlushSegmentedTabs(
                options: tabOptions,
                selection: Binding(
                    get: { model.kindFilter },
                    set: { model.setKindFilter($0) }
                )
            )

            Spacer(minLength: 8)

            // Plush Pill Search Field (shadow only on background capsule)
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PlushTheme.ink2)

                TextField(
                    "搜索文本或应用 (⌘F)",
                    text: Binding(
                        get: { model.searchText },
                        set: { model.handleSearchTextChange($0) }
                    )
                )
                .textFieldStyle(.plain)
                .font(PlushTheme.rounded(12.5, weight: .medium))
                .foregroundStyle(PlushTheme.ink)
                .focused($isSearchFocused)

                if !model.searchText.isEmpty {
                    Button {
                        model.handleSearchTextChange("")
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .buttonStyle(PlushCircleIconButtonStyle(diameter: 18, variant: .secondary))
                }
            }
            .padding(.horizontal, 12)
            .frame(width: 230, height: 34)
            .background(
                Capsule()
                    .fill(PlushTheme.surface)
                    .plushSoftShadow()
            )

            Button {
                model.refreshAll(showFeedback: true)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(PlushCircleIconButtonStyle(diameter: 34, variant: .surface))
            .help("刷新时间线 (⌘R)")

            Button {
                model.exportSelectedDay()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11.5, weight: .semibold))
                    Text("导出")
                }
            }
            .buttonStyle(PlushPillButtonStyle(variant: .surface, size: .sm))
            .disabled(model.selectedDay == nil)
            .help("导出当前日期 JSON")
        }
    }

    private var compactPermissionStrip: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PlushTheme.warning)
                    .frame(width: 24, height: 24)
                Image(systemName: "exclamationmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white)
            }

            Text(
                model.tapCreationFailed
                ? "监听未建立：如刚重新编译应用，请在系统设置中移除旧授权后重新勾选。"
                : "未开启「输入监控」权限，当前无法采集新的输入记录。"
            )
            .font(PlushTheme.rounded(12.5, weight: .medium))
            .foregroundStyle(PlushTheme.ink)
            .lineLimit(1)

            Spacer()

            Button("重检") {
                model.refreshAll(showFeedback: true)
            }
            .buttonStyle(PlushPillButtonStyle(variant: .secondary, size: .xs))

            Button("前往授权") {
                model.requestPermission()
            }
            .buttonStyle(PlushPillButtonStyle(variant: .primary, size: .xs))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: PlushTheme.Radius.row, style: .continuous)
                .fill(PlushTheme.warning.opacity(0.12))
        )
    }

    private func detailHeaderCard(timeline: DailyTimelinePage) -> some View {
        let header = TimelineFormatters.detailHeaderDisplay(timeline.date)
        let sortedApps = timeline.appCounts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }

        return VStack(alignment: .leading, spacing: 10) {
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

                    if model.kindFilter != .all || model.selectedAppFilter != nil || !model.searchText.isEmpty {
                        HStack(spacing: 6) {
                            Text("已筛选出 \(timeline.totalCount) 条")
                                .font(PlushTheme.rounded(11.5, weight: .medium).monospacedDigit())
                                .foregroundStyle(PlushTheme.ink2)

                            Button("清除筛选") {
                                withAnimation(PlushTheme.spring) {
                                    model.clearFilters()
                                }
                            }
                            .buttonStyle(.plain)
                            .font(PlushTheme.rounded(11.5, weight: .semibold))
                            .foregroundStyle(PlushTheme.selectA)
                        }
                    }
                }

                Spacer()

                // Odometer Counter summary badge
                VStack(alignment: .trailing, spacing: 1) {
                    Text("今日记录")
                        .font(PlushTheme.rounded(10.5, weight: .medium))
                        .foregroundStyle(PlushTheme.ink2)
                    Text("\(timeline.dayTotalCount)")
                        .font(PlushTheme.rounded(20, weight: .semibold).monospacedDigit())
                        .foregroundStyle(PlushTheme.ink)
                        .plushNumericTransition()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: PlushTheme.Radius.row, style: .continuous)
                        .fill(PlushTheme.fill)
                )
            }

            // Active Apps quick filter chips
            if !sortedApps.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(sortedApps.prefix(10), id: \.key) { appName, count in
                            let isSelected = model.selectedAppFilter?.caseInsensitiveCompare(appName) == .orderedSame
                            Button {
                                withAnimation(PlushTheme.spring) {
                                    model.toggleAppFilter(appName)
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    if let icon = AppIconProvider.shared.icon(for: appName) {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .interpolation(.high)
                                            .frame(width: 13, height: 13)
                                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                                    }
                                    Text(appName)
                                        .font(PlushTheme.rounded(11.5, weight: .semibold))
                                    Text("\(count)")
                                        .font(PlushTheme.rounded(10.5, weight: .semibold).monospacedDigit())
                                        .opacity(0.75)
                                }
                                .foregroundStyle(isSelected ? PlushTheme.onSelect : PlushTheme.ink2)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? AnyShapeStyle(PlushTheme.selectGradient) : AnyShapeStyle(PlushTheme.fill))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .plushCardSurface(cornerRadius: PlushTheme.Radius.card, background: PlushTheme.surface)
    }

    private func loadMoreRow(timeline: DailyTimelinePage) -> some View {
        let remaining = max(0, timeline.totalCount - timeline.loadedCount)
        return HStack {
            Spacer()
            Button {
                model.loadMoreItems()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 12, weight: .semibold))
                    Text("加载更早记录（剩余 \(remaining) 条）")
                }
            }
            .buttonStyle(PlushPillButtonStyle(variant: .surface, size: .sm))
            Spacer()
        }
        .padding(.vertical, 14)
    }

    // MARK: - Empty States

    private func filteredEmptyState(dayTotalCount: Int) -> some View {
        VStack(spacing: 14) {
            Spacer()
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(PlushTheme.fill)
                        .frame(width: 56, height: 56)
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(PlushTheme.ink2)
                }

                Text(dayTotalCount == 0 ? "当天暂无记录" : "没有匹配的记录")
                    .font(PlushTheme.rounded(16, weight: .semibold))
                    .foregroundStyle(PlushTheme.ink)

                if dayTotalCount > 0 {
                    Text("尝试更换搜索关键词、切换事件类型或清除应用筛选。")
                        .font(PlushTheme.rounded(13))
                        .foregroundStyle(PlushTheme.ink2)

                    Button("清除全部筛选") {
                        withAnimation(PlushTheme.spring) {
                            model.clearFilters()
                        }
                    }
                    .buttonStyle(PlushPillButtonStyle(variant: .primary, size: .sm))
                    .padding(.top, 4)
                }
            }
            .padding(28)
            .plushCardSurface(cornerRadius: PlushTheme.Radius.panel, background: PlushTheme.surface)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var permissionOnboardingState: some View {
        VStack(spacing: 16) {
            Spacer()
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(PlushTheme.warning.opacity(0.16))
                            .frame(width: 44, height: 44)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(PlushTheme.warning)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("开启输入监控权限")
                            .font(PlushTheme.rounded(18, weight: .semibold))
                            .foregroundStyle(PlushTheme.ink)
                        Text("只需三步即可本地记录输入与剪贴板时间线")
                            .font(PlushTheme.rounded(12.5))
                            .foregroundStyle(PlushTheme.ink2)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    onboardingStep(number: 1, text: "点击下方按钮，打开「系统设置 → 隐私与安全性 → 输入监控」", active: true)
                    onboardingStep(number: 2, text: "找到并勾选允许 InputTimeline（若刚重编译请先移除旧条目）", active: false)
                    onboardingStep(number: 3, text: "切回应用即可自动开始采集，所有数据仅保存于本机", active: false)
                }

                HStack(spacing: 10) {
                    Button("前往系统设置授权") {
                        model.requestPermission()
                    }
                    .buttonStyle(PlushPillButtonStyle(variant: .primary, size: .md))

                    Button("重新检查") {
                        model.refreshAll(showFeedback: true)
                    }
                    .buttonStyle(PlushPillButtonStyle(variant: .secondary, size: .md))
                }
            }
            .padding(26)
            .frame(maxWidth: 480)
            .plushCardSurface(cornerRadius: PlushTheme.Radius.panel, background: PlushTheme.surface)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private func onboardingStep(number: Int, text: String, active: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(active ? PlushTheme.accent : PlushTheme.fillStrong)
                    .frame(width: 24, height: 24)
                Text("\(number)")
                    .font(PlushTheme.rounded(12, weight: .semibold))
                    .foregroundStyle(active ? PlushTheme.onAccent : PlushTheme.ink2)
            }

            Text(text)
                .font(PlushTheme.rounded(12.5, weight: .medium))
                .foregroundStyle(PlushTheme.ink)
        }
    }

    private var noTimelineEmptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(model.isRecording ? PlushTheme.selectPlate : PlushTheme.fill)
                        .frame(width: 58, height: 58)
                    Image(systemName: model.isRecording ? "keyboard.fill" : "pause.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(model.isRecording ? PlushTheme.selectA : PlushTheme.ink2)
                }

                Text("暂无时间线记录")
                    .font(PlushTheme.rounded(17, weight: .semibold))
                    .foregroundStyle(PlushTheme.ink)

                Text(model.isRecording
                     ? "在其他应用打字或复制粘贴后，记录会自动出现在这里。"
                     : "当前记录已暂停，开启左下角开关即可开始采集。")
                    .font(PlushTheme.rounded(13))
                    .foregroundStyle(PlushTheme.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
            .padding(30)
            .plushCardSurface(cornerRadius: PlushTheme.Radius.panel, background: PlushTheme.surface)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

// MARK: - Isolated Sidebar Day Row (avoids re-rendering parent on hover)

private struct SidebarDayRow: View {
    let entry: TimelineFormatters.DayEntry
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isSelected ? AnyShapeStyle(PlushTheme.selectGradient) : AnyShapeStyle(Color.clear))
                    .frame(width: 7, height: 7)

                Text(entry.primary)
                    .font(PlushTheme.rounded(12.5, weight: isSelected ? .semibold : .medium).monospacedDigit())
                    .foregroundStyle(isSelected ? PlushTheme.ink : PlushTheme.ink2)

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
                    .fill(isSelected ? PlushTheme.surfaceElevated : (isHovered ? PlushTheme.fillStrong.opacity(0.65) : .clear))
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

// MARK: - Window Style Configurator (transparent integrated titlebar, no sidebar toggle)

private struct WindowStyleConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configureWindow(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindow(from: nsView)
        }
    }

    @MainActor
    private func configureWindow(from view: NSView) {
        guard let window = view.window else { return }
        if !window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.insert(.fullSizeContentView)
        }
        if !window.titlebarAppearsTransparent {
            window.titlebarAppearsTransparent = true
        }
        if window.titleVisibility != .hidden {
            window.titleVisibility = .hidden
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppModel.previewSample())
            .frame(width: 1080, height: 700)
    }
}
