import AppKit
import SwiftUI

enum SettingsNavigator {
    @MainActor
    static func open() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            if !NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("开启键盘与剪贴板记录", isOn: Binding(
                    get: { model.isRecording },
                    set: { model.toggleRecording($0) }
                ))

                Stepper(value: Binding(
                    get: { model.silenceGapSeconds },
                    set: { model.updateSilenceGap($0) }
                ), in: 1 ... 10) {
                    LabeledContent("键盘静默分段间隔") {
                        Text("\(model.silenceGapSeconds) 秒")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("采集与分段")
            } footer: {
                Text("连续按键超过该静默时长，或切换前台应用时，将自动切分为新的时间线记录。")
            }

            Section {
                Toggle("开机自动启动", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))

                LabeledContent("输入监控权限") {
                    HStack(spacing: 10) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(model.permissionGranted ? Color.green : Color.orange)
                                .frame(width: 7, height: 7)
                            Text(model.permissionGranted ? "已授权" : "未授权")
                                .foregroundStyle(.secondary)
                        }

                        Button("系统设置") {
                            model.requestPermission()
                        }

                        Button("重新检查") {
                            model.refreshAll()
                        }
                    }
                }
            } header: {
                Text("系统集成")
            } footer: {
                Text("登录项需安装到「应用程序」目录；若未生效，请在「系统设置 → 通用 → 登录项」中允许。")
            }

            Section {
                LabeledContent("数据目录") {
                    HStack(spacing: 8) {
                        Text(model.storageDirectoryPath)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Button("打开目录") {
                            model.revealStorageDirectory()
                        }
                    }
                }
            } header: {
                Text("存储与隐私")
            } footer: {
                Text("所有输入记录仅保存在本地 JSON 文件中；密码框等安全输入域通常不会被系统提供内容。")
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 390)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppModel.previewSample())
    }
}
