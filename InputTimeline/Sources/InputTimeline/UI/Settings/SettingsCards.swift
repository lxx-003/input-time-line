import SwiftUI

struct CaptureSettingsCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        SettingsCard(title: "采集与分段", icon: "waveform.path") {
            SettingsRow(
                title: "开启键盘与剪贴板记录",
                subtitle: "关闭后不会捕获任何输入或复制粘贴事件"
            ) {
                PlushSwitch(
                    isOn: Binding(
                        get: { model.isRecording },
                        set: { model.toggleRecording($0) }
                    ),
                    size: .regular
                )
            }

            Divider().opacity(0.45)

            SettingsRow(
                title: "键盘静默分段间隔",
                subtitle: "停顿超过该时长或切换应用时自动切分新记录"
            ) {
                PlushCounterStepper(
                    value: Binding(
                        get: { model.silenceGapSeconds },
                        set: { model.updateSilenceGap($0) }
                    ),
                    range: 1 ... 10,
                    unit: "秒"
                )
            }
        }
    }
}

struct PrivacyExclusionsCard: View {
    @EnvironmentObject private var model: AppModel
    @State private var newExcludedApp = ""

    var body: some View {
        SettingsCard(title: "隐私排除应用", icon: "eye.slash") {
            VStack(alignment: .leading, spacing: 10) {
                Text("当以下应用处于前台时，自动跳过键盘记录与剪贴板读取。")
                    .font(PlushTheme.rounded(12))
                    .foregroundStyle(PlushTheme.ink2)

                HStack(spacing: 8) {
                    TextField("输入应用名称，例如 1Password", text: $newExcludedApp)
                        .textFieldStyle(.plain)
                        .font(PlushTheme.rounded(12.5, weight: .medium))
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(
                            Capsule()
                                .fill(PlushTheme.fill)
                        )
                        .onSubmit {
                            addCustomExcludedApp()
                        }

                    Button("添加") {
                        addCustomExcludedApp()
                    }
                    .buttonStyle(PlushPillButtonStyle(variant: .primary, size: .sm))
                    .disabled(newExcludedApp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if !model.excludedApps.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(model.excludedApps, id: \.self) { appName in
                            HStack(spacing: 5) {
                                if let icon = AppIconProvider.shared.icon(for: appName) {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 13, height: 13)
                                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                                }
                                Text(appName)
                                    .font(PlushTheme.rounded(12, weight: .semibold))
                                    .foregroundStyle(PlushTheme.ink)

                                Button {
                                    withAnimation(PlushTheme.spring) {
                                        model.removeExcludedApp(appName)
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8.5, weight: .bold))
                                        .foregroundStyle(PlushTheme.ink2)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.leading, 9)
                            .padding(.trailing, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(PlushTheme.fillStrong))
                        }
                    }
                }

                let remainingSuggestions = RecordingPreference.suggestedSensitiveApps.filter { candidate in
                    !model.excludedApps.contains { $0.caseInsensitiveCompare(candidate) == .orderedSame }
                }

                if !remainingSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("快速添加常用隐私应用：")
                            .font(PlushTheme.rounded(11, weight: .medium))
                            .foregroundStyle(PlushTheme.ink3)

                        FlowLayout(spacing: 6) {
                            ForEach(remainingSuggestions, id: \.self) { appName in
                                Button {
                                    withAnimation(PlushTheme.spring) {
                                        model.addExcludedApp(appName)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 9, weight: .bold))
                                        Text(appName)
                                    }
                                    .font(PlushTheme.rounded(11.5, weight: .medium))
                                    .foregroundStyle(PlushTheme.ink2)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(PlushTheme.fill))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private func addCustomExcludedApp() {
        let trimmed = newExcludedApp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(PlushTheme.spring) {
            model.addExcludedApp(trimmed)
        }
        newExcludedApp = ""
    }
}

struct SystemStorageCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        SettingsCard(title: "系统集成与数据存储", icon: "internaldrive") {
            SettingsRow(
                title: "开机自动启动",
                subtitle: "建议将应用放入「应用程序」目录后开启"
            ) {
                PlushSwitch(
                    isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    ),
                    size: .regular
                )
            }

            Divider().opacity(0.45)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("输入监控权限")
                        .font(PlushTheme.rounded(13, weight: .semibold))
                        .foregroundStyle(PlushTheme.ink)
                    Text("系统级事件监听授权状态")
                        .font(PlushTheme.rounded(11.5))
                        .foregroundStyle(PlushTheme.ink2)
                }

                Spacer()

                PlushStatusBadge(
                    title: model.permissionGranted ? "已授权" : "未授权",
                    dotColor: model.permissionGranted ? PlushTheme.success : PlushTheme.warning,
                    isActive: model.permissionGranted
                )

                Button("重检") {
                    model.refreshAll(showFeedback: true)
                }
                .buttonStyle(PlushPillButtonStyle(variant: .secondary, size: .xs))

                Button("系统设置") {
                    model.requestPermission()
                }
                .buttonStyle(PlushPillButtonStyle(variant: .primary, size: .xs))
            }

            Divider().opacity(0.45)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("本地数据目录")
                        .font(PlushTheme.rounded(13, weight: .semibold))
                        .foregroundStyle(PlushTheme.ink)
                    Text(model.storageDirectoryPath)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(PlushTheme.ink2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Button("打开目录") {
                    model.revealStorageDirectory()
                }
                .buttonStyle(PlushPillButtonStyle(variant: .secondary, size: .xs))
            }
        }
    }
}
