import Foundation

extension AppModel {
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
}
