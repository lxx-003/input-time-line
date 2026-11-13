import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.stop()
    }
}

@main
struct InputTimelineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("Input Timeline", id: "main") {
            ContentView()
                .environmentObject(model)
                .onAppear {
                    appDelegate.model = model
                    model.start()
                }
        }
        .defaultSize(width: 1120, height: 740)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("刷新时间线") {
                    model.refreshAll(showFeedback: true)
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }

        MenuBarExtra {
            MenuBarContentView(openMainWindow: {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            })
            .environmentObject(model)
        } label: {
            Image(systemName: model.isRecording ? "keyboard.fill" : "keyboard")
                .help(model.isRecording ? "InputTimeline：正在记录" : "InputTimeline：已暂停")
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var copiedID: UUID?
    let openMainWindow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top Status Card
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.20))
                            .frame(width: 24, height: 24)
                        Circle()
                            .fill(statusColor)
                            .frame(width: 9, height: 9)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(menuStatusTitle)
                            .font(PlushTheme.rounded(13.5, weight: .semibold))
                            .foregroundStyle(PlushTheme.ink)
                        Text(menuStatusSubtitle)
                            .font(PlushTheme.rounded(11))
                            .foregroundStyle(PlushTheme.ink2)
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

                if !model.permissionGranted || model.tapCreationFailed {
                    Button {
                        model.requestPermission()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 11.5, weight: .semibold))
                            Text("授权输入监控权限")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PlushPillButtonStyle(variant: .primary, size: .xs))
                } else if model.isRecording {
                    HStack(spacing: 6) {
                        Text("快捷暂停：")
                            .font(PlushTheme.rounded(11, weight: .medium))
                            .foregroundStyle(PlushTheme.ink2)

                        ForEach([15, 30, 60], id: \.self) { minutes in
                            Button("\(minutes)m") {
                                model.pauseTemporarily(minutes: minutes)
                            }
                            .buttonStyle(PlushPillButtonStyle(variant: .secondary, size: .xs))
                        }

                        Spacer()
                    }
                }
            }
            .padding(12)
            .plushCardSurface(cornerRadius: PlushTheme.Radius.card, background: PlushTheme.surface)

            // Recent Records Quick Recall
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("最近记录（点击快速复制）")
                        .font(PlushTheme.rounded(11.5, weight: .semibold))
                        .foregroundStyle(PlushTheme.ink2)

                    Spacer()

                    if let count = model.selectedTimeline?.dayTotalCount, count > 0 {
                        Text("今日 \(count) 条")
                            .font(PlushTheme.rounded(11, weight: .semibold).monospacedDigit())
                            .foregroundStyle(PlushTheme.ink2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(PlushTheme.fillStrong))
                    }
                }
                .padding(.horizontal, 2)

                if model.recentMenuBarItems.isEmpty {
                    Text("暂无最近记录")
                        .font(PlushTheme.rounded(12))
                        .foregroundStyle(PlushTheme.ink3)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 18)
                        .plushCardSurface(cornerRadius: PlushTheme.Radius.row, background: PlushTheme.surface)
                } else {
                    VStack(spacing: 6) {
                        ForEach(model.recentMenuBarItems) { entry in
                            recentItemRow(entry)
                        }
                    }
                }
            }

            // Bottom Actions
            HStack(spacing: 8) {
                Button {
                    openMainWindow()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "macwindow")
                            .font(.system(size: 12, weight: .semibold))
                        Text("打开主窗口")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlushPillButtonStyle(variant: .primary, size: .sm))

                Button {
                    SettingsNavigator.open()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .buttonStyle(PlushCircleIconButtonStyle(diameter: 32, variant: .surface))
                .help("设置 (⌘,)")

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .buttonStyle(PlushCircleIconButtonStyle(diameter: 32, variant: .surface))
                .help("退出 InputTimeline (⌘Q)")
            }
        }
        .padding(14)
        .frame(width: 340)
        .background(PlushTheme.panel)
    }

    private func recentItemRow(_ entry: TimelineDisplayItem) -> some View {
        let theme = KindTheme(kind: entry.item.kind)
        let timeInfo = TimelineFormatters.timeLabel(for: entry.item)
        let isCopied = copiedID == entry.id

        return Button {
            model.copyItemText(entry, dayOverride: model.recentMenuBarDay)
            withAnimation(PlushTheme.popSpring) {
                copiedID = entry.id
            }
            Task {
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                if copiedID == entry.id {
                    withAnimation(PlushTheme.fastFade) {
                        copiedID = nil
                    }
                }
            }
        } label: {
            HStack(spacing: 9) {
                Circle()
                    .fill(isCopied ? PlushTheme.success : theme.accentColor)
                    .frame(width: 7, height: 7)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(entry.item.kind.rawValue)
                            .font(PlushTheme.rounded(10.5, weight: .semibold))
                            .foregroundStyle(theme.accentColor)

                        if let appName = entry.item.appName, !appName.isEmpty {
                            Text("· \(appName)")
                                .font(PlushTheme.rounded(10.5, weight: .medium))
                                .foregroundStyle(PlushTheme.ink2)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(timeInfo.clock)
                            .font(PlushTheme.rounded(10, weight: .medium).monospacedDigit())
                            .foregroundStyle(PlushTheme.ink3)
                    }

                    Text(TimelineFormatters.singleLineSnippet(entry.item.text, limit: 46))
                        .font(PlushTheme.body(12))
                        .foregroundStyle(PlushTheme.ink)
                        .lineLimit(1)
                }

                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isCopied ? PlushTheme.success : PlushTheme.ink3)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: PlushTheme.Radius.item, style: .continuous)
                    .fill(PlushTheme.surface)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
            .contentShape(RoundedRectangle(cornerRadius: PlushTheme.Radius.item, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        if !model.permissionGranted || model.tapCreationFailed {
            return PlushTheme.warning
        }
        return model.isRecording ? PlushTheme.success : PlushTheme.ink3
    }

    private var menuStatusTitle: String {
        if !model.permissionGranted || model.tapCreationFailed {
            return "监控未就绪"
        }
        return model.isRecording ? "正在采集中" : "已暂停采集"
    }

    private var menuStatusSubtitle: String {
        if !model.permissionGranted || model.tapCreationFailed {
            return "请开启输入监控权限"
        }
        if let resume = model.pauseResumeDate, !model.isRecording {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "将于 \(formatter.string(from: resume)) 自动恢复"
        }
        return model.isRecording ? "键盘与剪贴板实时记录中" : "点击右侧开关恢复"
    }
}
