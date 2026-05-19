import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    enum Paging {
        static let pageSize = 10
        static let previewTextLimit = 300
    }

    @Published var isRecording = false
    @Published var silenceGapSeconds = 2
    @Published var availableDays: [String] = []
    @Published var selectedDay: String?
    @Published var selectedTimeline: DailyTimelinePage?
    @Published var permissionGranted = PermissionHelper.inputMonitoringGranted()
    @Published var launchAtLogin = LaunchAtLoginManager.preferenceEnabled
    @Published var statusMessage = "记录关闭"

    private let pasteboard = NSPasteboard.general
    private let store = TimelineStore(silenceGapSeconds: 2)
    private var currentPage = 0
    private lazy var keyboardMonitor = KeyboardMonitor(
        onKeyboardText: { [weak self] text, appName, date in
            guard let self else { return }
            Task { await self.handleKeyboardText(text, appName: appName, at: date) }
        },
        onClipboardShortcut: { [weak self] action, date in
            guard let self else { return }
            Task { await self.handleClipboardShortcut(action, at: date) }
        }
    )

    func start() {
        syncLaunchAtLogin()
        refreshPermission()
        switch keyboardMonitor.start() {
        case .started, .alreadyRunning:
            if permissionGranted, statusMessage == "记录关闭" {
                statusMessage = isRecording ? "记录开启中" : "记录关闭"
            }
        case .permissionDenied:
            statusMessage = "需要输入监控权限"
        case .tapCreateFailed:
            statusMessage = "权限已授权，但监听未建立。若刚重建应用，请删除旧授权后重新授权。"
        }

        Task {
            await refreshDays()
            await loadInitialSelection()
        }
    }

    func stop() {
        keyboardMonitor.stop()
        Task {
            try? await store.flush()
        }
    }

    func toggleRecording(_ enabled: Bool) {
        isRecording = enabled
        statusMessage = enabled ? "记录开启中" : "记录关闭"

        Task {
            do {
                try await store.setRecording(enabled)
                if let selectedDay {
                    currentPage = 0
                    await loadTimeline(for: selectedDay, reset: true)
                }
            } catch {
                statusMessage = "切换记录状态失败: \(error.localizedDescription)"
            }
        }
    }

    func updateSilenceGap(_ value: Int) {
        silenceGapSeconds = value
        Task {
            do {
                try await store.setSilenceGapSeconds(value)
                if let selectedDay {
                    currentPage = 0
                    await loadTimeline(for: selectedDay, reset: true)
                }
            } catch {
                statusMessage = "更新静默间隔失败: \(error.localizedDescription)"
            }
        }
    }

    func refreshPermission() {
        permissionGranted = PermissionHelper.inputMonitoringGranted()
    }

    func syncLaunchAtLogin() {
        LaunchAtLoginManager.syncWithPreference()
        launchAtLogin = LaunchAtLoginManager.isRegistered
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        if let error = LaunchAtLoginManager.setEnabled(enabled) {
            launchAtLogin = LaunchAtLoginManager.isRegistered
            statusMessage = "登录项设置失败: \(error)"
            return
        }
        launchAtLogin = LaunchAtLoginManager.isRegistered
        if enabled && !launchAtLogin {
            statusMessage = "请在「系统设置 → 通用 → 登录项」中允许 InputTimeline 开机启动"
        }
    }

    func requestPermission() {
        PermissionHelper.requestInputMonitoring()
        PermissionHelper.openPrivacySettings()
        refreshPermission()
    }

    func selectDay(_ day: String) {
        selectedDay = day
        currentPage = 0
        Task {
            await loadTimeline(for: day, reset: true)
        }
    }

    func loadMoreItems() {
        guard let selectedDay, selectedTimeline?.hasMore == true else { return }

        currentPage += 1
        Task {
            await loadTimeline(for: selectedDay, reset: false)
        }
    }

    func exportSelectedDay() {
        guard let selectedDay else { return }

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
                }
            } catch {
                statusMessage = "导出失败: \(error.localizedDescription)"
            }
        }
    }

    private func handleKeyboardText(_ text: String, appName: String?, at date: Date) async {
        do {
            let day = try await store.handleKeyboardText(text, appName: appName, at: date)
            if let day {
                await afterStoreMutation(for: day)
            }
        } catch {
            statusMessage = "键盘记录失败: \(error.localizedDescription)"
        }
    }

    private func handleClipboardShortcut(_ action: ClipboardAction, at date: Date) async {
        let delay: UInt64 = action == .copy ? 150_000_000 : 0
        if delay > 0 {
            try? await Task.sleep(nanoseconds: delay)
        }

        let content = pasteboard.string(forType: .string) ?? ""
        let kind: TimelineItemKind = action == .copy ? .copy : .paste

        do {
            let day = try await store.handleClipboardEvent(kind: kind, text: content, at: date)
            if let day {
                await afterStoreMutation(for: day)
            }
        } catch {
            statusMessage = "剪贴板记录失败: \(error.localizedDescription)"
        }
    }

    private func afterStoreMutation(for day: String) async {
        await refreshDays()
        if selectedDay == nil || selectedDay == day {
            selectedDay = day
            currentPage = 0
            await loadTimeline(for: day, reset: true)
        }
    }

    private func refreshDays() async {
        do {
            availableDays = try await store.allAvailableDays()
        } catch {
            statusMessage = "读取日期列表失败: \(error.localizedDescription)"
        }
    }

    private func loadInitialSelection() async {
        if let first = availableDays.first {
            selectedDay = first
            currentPage = 0
            await loadTimeline(for: first, reset: true)
        }
    }

    private func loadTimeline(for day: String, reset: Bool) async {
        do {
            let page = try await store.timelinePage(
                for: day,
                page: currentPage,
                pageSize: Paging.pageSize,
                previewTextLimit: Paging.previewTextLimit
            )

            if reset || selectedTimeline?.date != day {
                selectedTimeline = page
            } else {
                let mergedItems = (selectedTimeline?.items ?? []) + page.items
                selectedTimeline = DailyTimelinePage(
                    date: page.date,
                    silenceGapSeconds: page.silenceGapSeconds,
                    items: mergedItems,
                    totalCount: page.totalCount,
                    loadedCount: mergedItems.count,
                    hasMore: page.hasMore
                )
            }
        } catch {
            statusMessage = "读取时间线失败: \(error.localizedDescription)"
        }
    }
}
