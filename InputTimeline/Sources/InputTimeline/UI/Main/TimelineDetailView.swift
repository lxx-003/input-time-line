import SwiftUI

struct TimelineDetailView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState.Binding var isSearchFocused: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Top Plush Control Bar (aligned horizontally with sidebar header below drag strip)
                topControlBar
                    .padding(.horizontal, 22)
                    .padding(.top, 36)
                    .padding(.bottom, 12)

                if (!model.permissionGranted || model.tapCreationFailed) && model.selectedTimeline != nil {
                    compactPermissionStrip
                        .padding(.horizontal, 22)
                        .padding(.bottom, 12)
                }

                if model.activeMainTab == .insights,
                   (model.permissionGranted || !model.availableDays.isEmpty),
                   let insights = model.selectedInsights {
                    InsightsDashboardView(insights: insights)
                } else if let timeline = model.selectedTimeline {
                    TimelineDetailHeaderCard(timeline: timeline)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 10)

                    kindFilterBar(timeline: timeline)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 10)

                    if timeline.items.isEmpty {
                        FilteredEmptyStateView(dayTotalCount: timeline.dayTotalCount)
                    } else {
                        ScrollViewReader { scrollProxy in
                            PlushScrollView {
                                LazyVStack(spacing: 8) {
                                    Color.clear
                                        .frame(height: 0)
                                        .id("timeline-top")

                                    ForEach(timeline.items) { entry in
                                        let isFilteredApp: Bool = {
                                            guard let activeApp = model.selectedAppFilter,
                                                  let entryApp = entry.item.appName,
                                                  !entryApp.isEmpty else {
                                                return false
                                            }
                                            return activeApp.caseInsensitiveCompare(entryApp) == .orderedSame
                                        }()

                                        TimelineCardView(
                                            entry: entry,
                                            searchQuery: timeline.activeSearchQuery,
                                            isFilteredApp: isFilteredApp,
                                            onCopy: { model.copyItemText(entry) },
                                            onInspect: { model.inspectFullText(entry) },
                                            onToggleAppFilter: { appName in
                                                model.toggleAppFilter(appName)
                                            }
                                        )
                                        .equatable()
                                    }

                                    if timeline.hasMore {
                                        loadMoreRow(timeline: timeline)
                                    }
                                }
                                .padding(.horizontal, 22)
                                .padding(.top, 4)
                                .padding(.bottom, 26)
                            }
                            .onChange(of: timelineFilterResetKey(timeline)) { _ in
                                scrollProxy.scrollTo("timeline-top", anchor: .top)
                            }
                        }
                    }
                } else if !model.permissionGranted {
                    PermissionOnboardingView()
                } else {
                    NoTimelineEmptyStateView()
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
        .ignoresSafeArea(.container, edges: .top)
    }

    private var topControlBar: some View {
        let mainTabOptions: [PlushTabOption<MainContentTab>] = [
            PlushTabOption(
                value: .timeline,
                title: "时间线",
                count: model.selectedTimeline?.dayTotalCount,
                dotColor: nil
            ),
            PlushTabOption(
                value: .insights,
                title: "统计洞察",
                count: nil,
                dotColor: PlushTheme.selectA
            )
        ]

        return HStack(spacing: 12) {
            PlushSegmentedTabs(
                options: mainTabOptions,
                selection: Binding(
                    get: { model.activeMainTab },
                    set: { model.setMainTab($0) }
                )
            )

            Spacer(minLength: 8)

            if model.activeMainTab == .timeline {
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
            }

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

    private func kindFilterBar(timeline: DailyTimelinePage) -> some View {
        let kindCounts = timeline.kindCounts
        let dayTotal = timeline.dayTotalCount
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
                count: kindCounts[.keyboard, default: 0],
                dotColor: PlushTheme.kindKeyboard
            ),
            PlushTabOption(
                value: .copy,
                title: "复制",
                count: kindCounts[.copy, default: 0],
                dotColor: PlushTheme.kindCopy
            ),
            PlushTabOption(
                value: .paste,
                title: "粘贴",
                count: kindCounts[.paste, default: 0],
                dotColor: PlushTheme.kindPaste
            )
        ]

        return HStack(spacing: 10) {
            PlushSegmentedTabs(
                options: tabOptions,
                selection: Binding(
                    get: { model.kindFilter },
                    set: { model.setKindFilter($0) }
                )
            )

            Spacer()
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

    private func timelineFilterResetKey(_ timeline: DailyTimelinePage) -> String {
        "\(timeline.date)|\(timeline.activeKindFilter?.rawValue ?? "")|\(timeline.activeAppFilter ?? "")|\(timeline.activeSearchQuery)"
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
}
