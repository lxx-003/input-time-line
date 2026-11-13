import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 224, ideal: 244, max: 280)
        } detail: {
            detail
        }
        .searchable(
            text: Binding(
                get: { model.searchText },
                set: { model.handleSearchTextChange($0) }
            ),
            prompt: "搜索文本或应用"
        )
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("事件类型", selection: Binding(
                    get: { model.kindFilter },
                    set: { model.setKindFilter($0) }
                )) {
                    ForEach(TimelineKindFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 230)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    model.exportSelectedDay()
                } label: {
                    Label("导出 JSON", systemImage: "square.and.arrow.up")
                }
                .disabled(model.selectedDay == nil)
                .help("导出当前日期 JSON")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.handleAppDidBecomeActive()
        }
        .sheet(item: $model.inspectedEntry) { entry in
            TimelineDetailSheet(entry: entry) { text in
                model.copyRawString(text)
            }
        }
        .frame(minWidth: 880, minHeight: 580)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            if model.availableDays.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Text("暂无历史日期")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("开启记录后按天归档")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                List(selection: Binding(
                    get: { model.selectedDay },
                    set: { day in
                        if let day {
                            model.selectDay(day)
                        }
                    }
                )) {
                    ForEach(TimelineFormatters.groupDays(model.availableDays)) { section in
                        Section(section.title) {
                            ForEach(section.days, id: \.self) { day in
                                dayRow(day)
                                    .tag(day)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .thinOverlayScrollbar()
            }

            Divider()

            sidebarFooter
        }
    }

    private var sidebarFooter: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusDotColor)
                .frame(width: 7, height: 7)

            Text(footerStatusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Toggle("", isOn: Binding(
                get: { model.isRecording },
                set: { model.toggleRecording($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var statusDotColor: Color {
        if !model.permissionGranted || model.tapCreationFailed {
            return .orange
        }
        return model.isRecording ? .green : .secondary
    }

    private var footerStatusText: String {
        if !model.permissionGranted || model.tapCreationFailed {
            return "未授权监控"
        }
        return model.isRecording ? "正在记录" : "已暂停"
    }

    private func dayRow(_ day: String) -> some View {
        let display = TimelineFormatters.sidebarDayDisplay(day)
        return HStack {
            Text(display.primary)
                .font(.system(size: 13).monospacedDigit())

            Spacer()

            if let badge = display.badge {
                Text(badge)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        VStack(spacing: 0) {
            if (!model.permissionGranted || model.tapCreationFailed) && model.selectedTimeline != nil {
                compactPermissionStrip
                Divider()
            }

            if let timeline = model.selectedTimeline {
                detailHeader(timeline: timeline)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Divider()

                if timeline.items.isEmpty {
                    filteredEmptyState(dayTotalCount: timeline.dayTotalCount)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(timeline.items.enumerated()), id: \.element.id) { index, entry in
                                TimelineCardView(
                                    entry: entry,
                                    isLast: index == timeline.items.count - 1 && !timeline.hasMore,
                                    onCopy: { model.copyItemText(entry) },
                                    onInspect: { model.inspectFullText(entry) }
                                )
                            }

                            if timeline.hasMore {
                                loadMoreRow(timeline: timeline)
                            }
                        }
                        .padding(.vertical, 6)
                        .thinOverlayScrollbar()
                    }
                }
            } else if !model.permissionGranted {
                permissionOnboardingState
            } else {
                noTimelineEmptyState
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var compactPermissionStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.orange)

            Text(
                model.tapCreationFailed
                ? "监听未建立：如刚重新编译应用，请在系统设置中移除旧授权后重新勾选。"
                : "未开启「输入监控」权限，当前无法采集新的输入记录。"
            )
            .font(.system(size: 12))
            .foregroundStyle(.primary)
            .lineLimit(1)

            Spacer()

            Button("前往授权") {
                model.requestPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("重检") {
                model.refreshAll()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.08))
    }

    private func detailHeader(timeline: DailyTimelinePage) -> some View {
        let header = TimelineFormatters.detailHeaderDisplay(timeline.date)
        let keyboardCount = timeline.kindCounts[.keyboard, default: 0]
        let copyCount = timeline.kindCounts[.copy, default: 0]
        let pasteCount = timeline.kindCounts[.paste, default: 0]

        return HStack(alignment: .firstTextBaseline) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(header.title)
                    .font(.system(size: 20, weight: .semibold))

                if let tag = header.subtitleTag {
                    Text(tag)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("共 \(timeline.dayTotalCount) 条 · 键盘 \(keyboardCount) · 复制 \(copyCount) · 粘贴 \(pasteCount)")
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func loadMoreRow(timeline: DailyTimelinePage) -> some View {
        let remaining = max(0, timeline.totalCount - timeline.loadedCount)
        return HStack {
            Spacer()
            Button("加载更早记录（剩余 \(remaining) 条）") {
                model.loadMoreItems()
            }
            .buttonStyle(.link)
            .font(.system(size: 12.5))
            Spacer()
        }
        .padding(.vertical, 14)
    }

    // MARK: - Empty States

    private func filteredEmptyState(dayTotalCount: Int) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text(dayTotalCount == 0 ? "当天暂无记录" : "没有匹配的记录")
                .font(.headline)

            if dayTotalCount > 0 {
                Text("尝试更换关键词或切换事件类型。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("清除筛选") {
                    model.clearFilters()
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var permissionOnboardingState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 38))
                .foregroundStyle(.orange)

            VStack(spacing: 6) {
                Text("需要开启输入监控权限")
                    .font(.title3.weight(.semibold))
                Text("打开「系统设置 → 隐私与安全性 → 输入监控」允许 InputTimeline 后，切回应用即可自动开始记录。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            HStack(spacing: 10) {
                Button("请求权限并打开系统设置") {
                    model.requestPermission()
                }
                .buttonStyle(.borderedProminent)

                Button("重新检查") {
                    model.refreshAll()
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var noTimelineEmptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "clock")
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)
            Text("暂无时间线记录")
                .font(.headline)
            Text(model.isRecording
                 ? "在其他应用打字或复制粘贴后，记录会自动出现在这里。"
                 : "当前记录已暂停，开启左下角开关即可开始采集。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppModel.previewSample())
            .frame(width: 1040, height: 680)
    }
}
