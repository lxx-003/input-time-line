import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    enum Paging {
        static let pageSize = 30
        static let previewTextLimit = 420
    }

    @Published var isRecording = RecordingPreference.enabled
    @Published var silenceGapSeconds = RecordingPreference.silenceGapSeconds
    @Published var excludedApps: [String] = RecordingPreference.excludedApps
    @Published var availableDays: [String] = []
    @Published var availableDaySet: Set<String> = []
    @Published var groupedDaySections: [TimelineFormatters.DaySection] = []
    @Published var selectedDay: String?
    @Published var selectedTimeline: DailyTimelinePage?
    @Published var permissionGranted = PermissionHelper.inputMonitoringGranted()
    @Published var tapCreationFailed = false
    @Published var launchAtLogin = LaunchAtLoginManager.preferenceEnabled
    @Published var statusMessage = RecordingPreference.enabled ? "记录开启中" : "记录已暂停"
    @Published var activeMainTab: MainContentTab = .timeline
    var lastNonSettingsTab: MainContentTab = .timeline
    @Published var insightsRange: InsightsDateRange = .forPreset(.today)
    @Published var kindFilter: TimelineKindFilter = .all
    @Published var selectedAppFilter: String?
    @Published var searchText = ""
    @Published var selectedInsights: DailyInsights?
    @Published var inspectedEntry: InspectedTimelineEntry?
    @Published var storageDirectoryPath = "~/Library/Application Support/InputTimeline"
    @Published var activeToast: PlushToastMessage?
    @Published var pauseResumeDate: Date?
    @Published var recentMenuBarItems: [TimelineDisplayItem] = []
    @Published var recentMenuBarDay: String?
    @Published var isCalendarExpanded = true

    let pasteboard = NSPasteboard.general
    let store = TimelineStore(
        silenceGapSeconds: RecordingPreference.silenceGapSeconds,
        isRecording: RecordingPreference.enabled
    )
    let isPreviewMode: Bool
    var currentPage = 0
    var searchDebounceTask: Task<Void, Never>?
    var toastDismissTask: Task<Void, Never>?
    var pauseTimerTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var insightsLoadTask: Task<Void, Never>?
    private var insightsRefreshTask: Task<Void, Never>?

    var isInsightsMultiDayMode: Bool {
        activeMainTab == .insights && !insightsRange.isSingleDay
    }

    var sidebarHighlightedRangeDays: Set<String> {
        isInsightsMultiDayMode ? insightsRange.highlightedDaySet : []
    }

    private lazy var keyboardMonitor = KeyboardMonitor(
        onKeyboardText: { [weak self] text, appName, date in
            guard let self else { return }
            Task { await self.handleKeyboardText(text, appName: appName, at: date) }
        },
        onClipboardShortcut: { [weak self] action, appName, date in
            guard let self else { return }
            Task { await self.handleClipboardShortcut(action, appName: appName, at: date) }
        },
        onKeyPress: { [weak self] keyCode, appName, date in
            guard let self else { return }
            Task { await self.handleKeyPress(keyCode, appName: appName, at: date) }
        }
    )

    init(previewMode: Bool = false) {
        self.isPreviewMode = previewMode
    }

    func start() {
        guard !isPreviewMode else { return }
        syncLaunchAtLogin()
        syncRecording()
        refreshPermission()
        startMonitorIfPossible()

        Task {
            if let dir = try? await store.storageDirectoryURL() {
                storageDirectoryPath = (dir.path as NSString).abbreviatingWithTildeInPath
            }
            await refreshDays()
            await loadInitialSelection()
            await refreshMenuBarRecents()
        }
    }

    func refreshAll(showFeedback: Bool = false) {
        guard !isPreviewMode else { return }
        refreshPermission()
        startMonitorIfPossible()
        Task {
            await refreshDays()
            if let selectedDay {
                currentPage = 0
                await scheduleLoadTimeline(for: selectedDay, reset: true)
            } else {
                await loadInitialSelection()
            }
            if activeMainTab == .insights {
                await loadInsights(for: insightsRange)
            }
            await refreshMenuBarRecents()
            if showFeedback {
                showToast(title: "时间线已刷新", tone: .info)
            }
        }
    }

    func handleAppDidBecomeActive() {
        guard !isPreviewMode else { return }
        let wasBlocked = !permissionGranted || tapCreationFailed
        refreshPermission()
        startMonitorIfPossible()

        Task {
            let previousDays = availableDays
            await refreshDays()
            if availableDays != previousDays, selectedDay == nil {
                await loadInitialSelection()
            } else if wasBlocked && permissionGranted && !tapCreationFailed, let selectedDay {
                currentPage = 0
                await scheduleLoadTimeline(for: selectedDay, reset: true)
            }
            await refreshMenuBarRecents()
        }
    }

    func stop() {
        guard !isPreviewMode else { return }
        pauseTimerTask?.cancel()
        toastDismissTask?.cancel()
        insightsLoadTask?.cancel()
        insightsRefreshTask?.cancel()
        keyboardMonitor.stop()
        Task {
            try? await store.flush()
        }
    }

    func startMonitorIfPossible() {
        switch keyboardMonitor.start() {
        case .started, .alreadyRunning:
            tapCreationFailed = false
            if permissionGranted {
                statusMessage = isRecording ? "记录开启中" : "记录已暂停"
            }
        case .permissionDenied:
            tapCreationFailed = false
            statusMessage = "需要输入监控权限"
        case .tapCreateFailed:
            tapCreationFailed = true
            statusMessage = "权限已授权，但监听未建立。若刚重建应用，请删除旧授权后重新授权。"
        }
    }

    func scheduleLoadTimeline(for day: String, reset: Bool) async {
        loadTask?.cancel()
        let pageToLoad = currentPage
        let activeFilter = kindFilter.itemKind
        let activeApp = selectedAppFilter
        let activeSearch = searchText

        let task = Task { [weak self] in
            guard let self else { return }
            await self.loadTimeline(
                for: day,
                page: pageToLoad,
                kindFilter: activeFilter,
                appFilter: activeApp,
                searchQuery: activeSearch,
                reset: reset
            )
        }
        loadTask = task
        await task.value
    }

    private func handleKeyPress(_ keyCode: Int, appName: String?, at date: Date) async {
        guard !isAppExcluded(appName) else { return }
        do {
            if let day = try await store.handleKeyPress(keyCode: keyCode, at: date) {
                await refreshDays()
                if selectedDay == nil || selectedDay == day {
                    selectedDay = day
                    if selectedTimeline?.date != day {
                        await scheduleLoadTimeline(for: day, reset: true)
                    }
                }
                if activeMainTab == .insights && insightsRange.highlightedDaySet.contains(day) {
                    scheduleInsightsRefresh(for: insightsRange)
                }
            }
        } catch {
            // Keep key-count tracking silent unless timeline write fails
        }
    }

    private func scheduleInsightsRefresh(for range: InsightsDateRange) {
        insightsRefreshTask?.cancel()
        insightsRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, let self else { return }
            await self.loadInsights(for: range)
        }
    }

    func loadInsights(for range: InsightsDateRange) async {
        guard !isPreviewMode else { return }
        insightsLoadTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            let loaded = try? await self.store.insights(for: range)
            guard !Task.isCancelled, let loaded, self.insightsRange == range else { return }
            self.selectedInsights = loaded
        }
        insightsLoadTask = task
        await task.value
    }

    private func handleKeyboardText(_ text: String, appName: String?, at date: Date) async {
        guard !isAppExcluded(appName) else { return }
        do {
            let day = try await store.handleKeyboardText(text, appName: appName, at: date)
            if let day {
                await afterStoreMutation(for: day)
            }
        } catch {
            statusMessage = "键盘记录失败: \(error.localizedDescription)"
        }
    }

    private func handleClipboardShortcut(_ action: ClipboardAction, appName: String?, at date: Date) async {
        guard !isAppExcluded(appName) else { return }

        let delay: UInt64 = action == .copy ? 150_000_000 : 0
        if delay > 0 {
            try? await Task.sleep(nanoseconds: delay)
        }

        let content = pasteboard.string(forType: .string) ?? ""
        let kind: TimelineItemKind = action == .copy ? .copy : .paste

        do {
            let day = try await store.handleClipboardEvent(kind: kind, appName: appName, text: content, at: date)
            if let day {
                await afterStoreMutation(for: day)
            }
        } catch {
            statusMessage = "剪贴板记录失败: \(error.localizedDescription)"
        }
    }

    private func afterStoreMutation(for day: String) async {
        await refreshDays()
        await refreshMenuBarRecents()
        if selectedDay == nil || selectedDay == day {
            selectedDay = day
            currentPage = 0
            await scheduleLoadTimeline(for: day, reset: true)
        }
        if activeMainTab == .insights && insightsRange.highlightedDaySet.contains(day) && !insightsRange.isSingleDay {
            await loadInsights(for: insightsRange)
        }
    }

    private func refreshMenuBarRecents() async {
        if let recents = try? await store.recentEntries(limit: 4, previewTextLimit: 160) {
            recentMenuBarDay = recents.day
            recentMenuBarItems = recents.items
        }
    }

    private func refreshDays() async {
        do {
            let days = try await store.allAvailableDays()
            if days != availableDays {
                availableDays = days
                availableDaySet = Set(days)
                groupedDaySections = TimelineFormatters.groupDays(days)
            }
        } catch {
            statusMessage = "读取日期列表失败: \(error.localizedDescription)"
        }
    }

    private func loadInitialSelection() async {
        if let first = availableDays.first {
            selectedDay = first
            insightsRange = .singleDay(first)
            currentPage = 0
            await scheduleLoadTimeline(for: first, reset: true)
        } else {
            selectedDay = nil
            selectedTimeline = nil
            selectedInsights = nil
        }
    }

    private func loadTimeline(
        for day: String,
        page: Int,
        kindFilter: TimelineItemKind?,
        appFilter: String?,
        searchQuery: String,
        reset: Bool
    ) async {
        do {
            let loadedPage = try await store.timelinePage(
                for: day,
                page: page,
                pageSize: Paging.pageSize,
                previewTextLimit: Paging.previewTextLimit,
                kindFilter: kindFilter,
                appFilter: appFilter,
                searchQuery: searchQuery
            )

            guard !Task.isCancelled else { return }

            if reset || selectedTimeline?.date != day {
                if insightsRange.isSingleDay && (insightsRange.startDay == day || selectedDay == day) {
                    let rangeToLoad = InsightsDateRange.singleDay(day)
                    let insights = try? await store.insights(for: rangeToLoad)
                    guard !Task.isCancelled else { return }
                    if insightsRange.isSingleDay {
                        insightsRange = rangeToLoad
                        selectedInsights = insights
                    }
                }
                selectedTimeline = loadedPage
            } else {
                let mergedItems = (selectedTimeline?.items ?? []) + loadedPage.items
                selectedTimeline = DailyTimelinePage(
                    date: loadedPage.date,
                    silenceGapSeconds: loadedPage.silenceGapSeconds,
                    items: mergedItems,
                    totalCount: loadedPage.totalCount,
                    dayTotalCount: loadedPage.dayTotalCount,
                    kindCounts: loadedPage.kindCounts,
                    appCounts: loadedPage.appCounts,
                    sortedApps: loadedPage.sortedApps,
                    activeKindFilter: loadedPage.activeKindFilter,
                    activeAppFilter: loadedPage.activeAppFilter,
                    activeSearchQuery: loadedPage.activeSearchQuery,
                    loadedCount: mergedItems.count,
                    hasMore: loadedPage.hasMore
                )
            }
        } catch {
            if !Task.isCancelled {
                statusMessage = "读取时间线失败: \(error.localizedDescription)"
            }
        }
    }
}
