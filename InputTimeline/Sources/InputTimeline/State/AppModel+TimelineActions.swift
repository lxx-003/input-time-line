import AppKit
import Foundation
import SwiftUI

extension AppModel {
    func selectDay(_ day: String) {
        if activeMainTab == .settings {
            activeMainTab = lastNonSettingsTab
        }
        selectedDay = day
        currentPage = 0
        selectedAppFilter = nil
        let targetRange = InsightsDateRange.singleDay(day)
        insightsRange = targetRange
        guard !isPreviewMode else { return }
        Task {
            await scheduleLoadTimeline(for: day, reset: true)
            if activeMainTab == .insights {
                await loadInsights(for: targetRange)
            }
        }
    }

    func setMainTab(_ tab: MainContentTab) {
        if tab != .settings {
            lastNonSettingsTab = tab
        }
        guard activeMainTab != tab else { return }
        activeMainTab = tab
        guard tab == .insights else { return }
        if insightsRange.isSingleDay, let selectedDay, insightsRange.startDay != selectedDay {
            insightsRange = .singleDay(selectedDay)
        }
        guard !isPreviewMode else { return }
        if selectedInsights?.range != insightsRange {
            let target = insightsRange
            Task {
                await loadInsights(for: target)
            }
        }
    }

    func openSettings() {
        if activeMainTab != .settings {
            lastNonSettingsTab = activeMainTab
        }
        activeMainTab = .settings
    }

    func closeSettings() {
        guard activeMainTab == .settings else { return }
        setMainTab(lastNonSettingsTab)
    }

    func toggleSettings() {
        if activeMainTab == .settings {
            closeSettings()
        } else {
            openSettings()
        }
    }

    func setInsightsPreset(_ preset: InsightsRangePreset) {
        setInsightsRange(InsightsDateRange.forPreset(preset))
    }

    func setInsightsRange(_ range: InsightsDateRange) {
        insightsRange = range
        if range.isSingleDay {
            selectedDay = range.startDay
            currentPage = 0
            selectedAppFilter = nil
        }
        guard !isPreviewMode else { return }
        Task {
            await loadInsights(for: range)
            if range.isSingleDay {
                await scheduleLoadTimeline(for: range.startDay, reset: true)
            }
        }
    }

    func setKindFilter(_ filter: TimelineKindFilter) {
        if activeMainTab != .timeline {
            activeMainTab = .timeline
        }
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

    private func writeToPasteboard(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
