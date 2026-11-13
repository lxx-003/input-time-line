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
    @Published var kindFilter: TimelineKindFilter = .all
    @Published var selectedAppFilter: String?
    @Published var searchText = ""
    @Published var inspectedEntry: InspectedTimelineEntry?
    @Published var storageDirectoryPath = "~/Library/Application Support/InputTimeline"
    @Published var activeToast: PlushToastMessage?
    @Published var pauseResumeDate: Date?
    @Published var recentMenuBarItems: [TimelineDisplayItem] = []
    @Published var recentMenuBarDay: String?
    @Published var isCalendarExpanded = true

    private let pasteboard = NSPasteboard.general
    private let store = TimelineStore(
        silenceGapSeconds: RecordingPreference.silenceGapSeconds,
        isRecording: RecordingPreference.enabled
    )
    private let isPreviewMode: Bool
    private var currentPage = 0
    private var loadTask: Task<Void, Never>?
    private var searchDebounceTask: Task<Void, Never>?
    private var toastDismissTask: Task<Void, Never>?
    private var pauseTimerTask: Task<Void, Never>?

    private lazy var keyboardMonitor = KeyboardMonitor(
        onKeyboardText: { [weak self] text, appName, date in
            guard let self else { return }
            Task { await self.handleKeyboardText(text, appName: appName, at: date) }
        },
        onClipboardShortcut: { [weak self] action, appName, date in
            guard let self else { return }
            Task { await self.handleClipboardShortcut(action, appName: appName, at: date) }
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
        keyboardMonitor.stop()
        Task {
            try? await store.flush()
        }
    }

    func syncRecording() {
        let enabled = RecordingPreference.enabled
        isRecording = enabled
        statusMessage = enabled ? "记录开启中" : "记录已暂停"
        Task {
            try? await store.setRecording(enabled)
        }
    }

    func toggleRecording(_ enabled: Bool) {
        if enabled {
            pauseTimerTask?.cancel()
            pauseResumeDate = nil
        }

        RecordingPreference.enabled = enabled
        isRecording = enabled
        statusMessage = enabled ? "记录开启中" : "记录已暂停"
        guard !isPreviewMode else { return }

        Task {
            do {
                try await store.setRecording(enabled)
                if let selectedDay {
                    currentPage = 0
                    await scheduleLoadTimeline(for: selectedDay, reset: true)
                }
                showToast(
                    title: enabled ? "已开启记录" : "已暂停记录",
                    subtitle: enabled ? "键盘与剪贴板事件恢复采集" : "不会记录新的输入或剪贴板内容",
                    tone: enabled ? .success : .warning
                )
            } catch {
                statusMessage = "切换记录状态失败: \(error.localizedDescription)"
                showToast(title: "切换状态失败", subtitle: error.localizedDescription, tone: .error)
            }
        }
    }

    func pauseTemporarily(minutes: Int) {
        pauseTimerTask?.cancel()
        let resumeAt = Date().addingTimeInterval(TimeInterval(minutes * 60))
        pauseResumeDate = resumeAt

        RecordingPreference.enabled = false
        isRecording = false
        statusMessage = "已暂停 \(minutes) 分钟"

        guard !isPreviewMode else { return }

        Task {
            try? await store.setRecording(false)
            if let selectedDay {
                currentPage = 0
                await scheduleLoadTimeline(for: selectedDay, reset: true)
            }
        }

        showToast(
            title: "已暂停记录 \(minutes) 分钟",
            subtitle: "到期后将自动恢复采集",
            tone: .warning
        )

        pauseTimerTask = Task { [weak self] in
            let nanos = UInt64(minutes) * 60 * 1_000_000_000
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled, let self else { return }
            self.pauseResumeDate = nil
            self.toggleRecording(true)
        }
    }

    func updateSilenceGap(_ value: Int) {
        let clamped = min(10, max(1, value))
        silenceGapSeconds = clamped
        RecordingPreference.silenceGapSeconds = clamped
        guard !isPreviewMode else { return }

        Task {
            do {
                try await store.setSilenceGapSeconds(clamped)
                if let selectedDay {
                    currentPage = 0
                    await scheduleLoadTimeline(for: selectedDay, reset: true)
                }
            } catch {
                statusMessage = "更新静默间隔失败: \(error.localizedDescription)"
                showToast(title: "更新间隔失败", subtitle: error.localizedDescription, tone: .error)
            }
        }
    }

    func addExcludedApp(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !excludedApps.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            return
        }
        excludedApps.append(trimmed)
        RecordingPreference.excludedApps = excludedApps
    }

    func removeExcludedApp(_ name: String) {
        excludedApps.removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
        RecordingPreference.excludedApps = excludedApps
    }

    func isAppExcluded(_ appName: String?) -> Bool {
        guard let appName = appName?.trimmingCharacters(in: .whitespacesAndNewlines), !appName.isEmpty else {
            return false
        }
        return excludedApps.contains { $0.caseInsensitiveCompare(appName) == .orderedSame }
    }

    func refreshPermission() {
        guard !isPreviewMode else { return }
        permissionGranted = PermissionHelper.inputMonitoringGranted()
    }

    func syncLaunchAtLogin() {
        LaunchAtLoginManager.syncWithPreference()
        launchAtLogin = LaunchAtLoginManager.isRegistered
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        guard !isPreviewMode else { return }

        if let error = LaunchAtLoginManager.setEnabled(enabled) {
            launchAtLogin = LaunchAtLoginManager.isRegistered
            statusMessage = "登录项设置失败: \(error)"
            showToast(title: "登录项设置失败", subtitle: error, tone: .error)
            return
        }
        launchAtLogin = LaunchAtLoginManager.isRegistered
        if enabled && !launchAtLogin {
            statusMessage = "请在「系统设置 → 通用 → 登录项」中允许 InputTimeline 开机启动"
            showToast(title: "需要在系统设置中允许开机启动", tone: .warning)
        }
    }

    func requestPermission() {
        guard !isPreviewMode else { return }
        PermissionHelper.requestInputMonitoring()
        PermissionHelper.openPrivacySettings()
        refreshPermission()
    }

    func selectDay(_ day: String) {
        selectedDay = day
        currentPage = 0
        selectedAppFilter = nil
        guard !isPreviewMode else { return }
        Task {
            await scheduleLoadTimeline(for: day, reset: true)
        }
    }

    func setKindFilter(_ filter: TimelineKindFilter) {
        guard kindFilter != filter else { return }
        kindFilter = filter
        currentPage = 0
        guard !isPreviewMode, let selectedDay else { return }
        Task {
            await scheduleLoadTimeline(for: selectedDay, reset: true)
        }
    }

    func toggleAppFilter(_ appName: String) {
        if selectedAppFilter?.caseInsensitiveCompare(appName) == .orderedSame {
            selectedAppFilter = nil
        } else {
            selectedAppFilter = appName
        }
        currentPage = 0
        guard !isPreviewMode, let selectedDay else { return }
        Task {
            await scheduleLoadTimeline(for: selectedDay, reset: true)
        }
    }

    func handleSearchTextChange(_ text: String) {
        searchText = text
        currentPage = 0
        guard !isPreviewMode, let selectedDay else { return }

        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            await scheduleLoadTimeline(for: selectedDay, reset: true)
        }
    }

    func clearFilters() {
        kindFilter = .all
        selectedAppFilter = nil
        searchText = ""
        currentPage = 0
        guard !isPreviewMode, let selectedDay else { return }
        Task {
            await scheduleLoadTimeline(for: selectedDay, reset: true)
        }
    }

    func loadMoreItems() {
        guard !isPreviewMode, let selectedDay, selectedTimeline?.hasMore == true else { return }

        currentPage += 1
        Task {
            await scheduleLoadTimeline(for: selectedDay, reset: false)
        }
    }

    func copyItemText(_ displayItem: TimelineDisplayItem, dayOverride: String? = nil) {
        if isPreviewMode || !displayItem.isTruncated {
            writeToPasteboard(displayItem.item.text)
            showToast(title: "已复制到剪贴板", subtitle: "\(displayItem.originalCharacterCount) 个字符", tone: .success)
            return
        }

        let day = dayOverride ?? selectedDay ?? ""
        Task {
            let text = (try? await store.fullText(for: day, matching: displayItem.item)) ?? displayItem.item.text
            writeToPasteboard(text)
            showToast(title: "已复制完整原文", subtitle: "\(text.count) 个字符", tone: .success)
        }
    }

    func inspectFullText(_ displayItem: TimelineDisplayItem) {
        if isPreviewMode || !displayItem.isTruncated {
            inspectedEntry = InspectedTimelineEntry(
                id: displayItem.id,
                item: displayItem.item,
                fullText: displayItem.item.text
            )
            return
        }

        let day = selectedDay ?? ""
        Task {
            let full = (try? await store.fullText(for: day, matching: displayItem.item)) ?? displayItem.item.text
            inspectedEntry = InspectedTimelineEntry(
                id: displayItem.id,
                item: displayItem.item,
                fullText: full
            )
        }
    }

    func copyRawString(_ text: String) {
        writeToPasteboard(text)
        showToast(title: "已复制完整原文", subtitle: "\(text.count) 个字符", tone: .success)
    }

    func revealStorageDirectory() {
        Task {
            if let url = try? await store.storageDirectoryURL() {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func exportSelectedDay() {
        guard !isPreviewMode, let selectedDay else { return }

        Task {
            do {
                let sourceURL = try await store.exportFileURL(for: selectedDay)
                let panel = NSSavePanel()
                panel.canCreateDirectories = true
                panel.nameFieldStringValue = "\(selectedDay).json"
                panel.allowedContentTypes = [.json]
                if panel.runModal() == .OK, let targetURL = panel.url {
                    if FileManager.default.fileExists(atPath: targetURL.path) {
                        try FileManager.default.removeItem(at: targetURL)
                    }
                    try FileManager.default.copyItem(at: sourceURL, to: targetURL)
                    statusMessage = "已导出 \(selectedDay).json"
                    showToast(title: "导出成功", subtitle: targetURL.lastPathComponent, tone: .success)
                }
            } catch {
                statusMessage = "导出失败: \(error.localizedDescription)"
                showToast(title: "导出失败", subtitle: error.localizedDescription, tone: .error)
            }
        }
    }

    func showToast(title: String, subtitle: String? = nil, tone: PlushToastMessage.Tone = .success) {
        toastDismissTask?.cancel()
        let message = PlushToastMessage(title: title, subtitle: subtitle, tone: tone)
        withAnimation(PlushTheme.spring) {
            activeToast = message
        }
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_300_000_000)
            guard !Task.isCancelled, let self else { return }
            if self.activeToast?.id == message.id {
                withAnimation(PlushTheme.softSpring) {
                    self.activeToast = nil
                }
            }
        }
    }

    func dismissToast() {
        toastDismissTask?.cancel()
        withAnimation(PlushTheme.softSpring) {
            activeToast = nil
        }
    }

    private func startMonitorIfPossible() {
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

    private func writeToPasteboard(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
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
            currentPage = 0
            await scheduleLoadTimeline(for: first, reset: true)
        } else {
            selectedDay = nil
            selectedTimeline = nil
        }
    }

    private func scheduleLoadTimeline(for day: String, reset: Bool) async {
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

extension AppModel {
    static func previewSample() -> AppModel {
        let model = AppModel(previewMode: true)
        model.permissionGranted = true
        model.isRecording = true
        model.launchAtLogin = true
        model.statusMessage = "记录开启中"
        model.availableDays = ["2026-11-13", "2026-11-12", "2026-11-10"]
        model.availableDaySet = Set(model.availableDays)
        model.groupedDaySections = TimelineFormatters.groupDays(model.availableDays)
        model.selectedDay = "2026-11-13"

        let sampleItems: [TimelineDisplayItem] = [
            TimelineDisplayItem(
                id: UUID(),
                item: TimelineItem(
                    kind: .keyboard,
                    start: "2026-11-13 14:32:10",
                    end: "2026-11-13 14:32:24",
                    appName: "Cursor",
                    text: "重构 ContentView 的时间线卡片样式，加上应用图标和工具栏筛选\r"
                ),
                originalCharacterCount: 38,
                isTruncated: false
            ),
            TimelineDisplayItem(
                id: UUID(),
                item: TimelineItem(
                    kind: .copy,
                    at: "2026-11-13 14:28:03",
                    appName: "Safari",
                    text: "NavigationSplitView {\n    SidebarView()\n} detail: {\n    TimelineDetailView()\n}"
                ),
                originalCharacterCount: 78,
                isTruncated: false
            ),
            TimelineDisplayItem(
                id: UUID(),
                item: TimelineItem(
                    kind: .paste,
                    at: "2026-11-13 14:28:09",
                    appName: "Cursor",
                    text: "NavigationSplitView {\n    SidebarView()\n} detail: {\n    TimelineDetailView()\n}"
                ),
                originalCharacterCount: 78,
                isTruncated: false
            ),
            TimelineDisplayItem(
                id: UUID(),
                item: TimelineItem(
                    kind: .keyboard,
                    start: "2026-11-13 14:15:02",
                    end: "2026-11-13 14:15:18",
                    appName: "Safari",
                    text: "macOS SwiftUI NavigationSplitView toolbar searchable design"
                ),
                originalCharacterCount: 59,
                isTruncated: false
            )
        ]

        model.recentMenuBarDay = "2026-11-13"
        model.recentMenuBarItems = sampleItems
        model.selectedTimeline = DailyTimelinePage(
            date: "2026-11-13",
            silenceGapSeconds: 2,
            items: sampleItems,
            totalCount: 4,
            dayTotalCount: 24,
            kindCounts: [.keyboard: 15, .copy: 5, .paste: 4],
            appCounts: ["Cursor": 14, "Safari": 10],
            loadedCount: 4,
            hasMore: true
        )
        return model
    }
}
