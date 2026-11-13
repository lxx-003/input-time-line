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
        .defaultSize(width: 1080, height: 720)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("刷新时间线") {
                    model.refreshAll()
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
    }
}

private struct MenuBarContentView: View {
    @EnvironmentObject private var model: AppModel
    let openMainWindow: () -> Void

    var body: some View {
        Text(menuStatusTitle)
            .font(.caption)

        Divider()

        Button(model.isRecording ? "暂停记录" : "开启记录") {
            model.toggleRecording(!model.isRecording)
        }

        if !model.permissionGranted {
            Button("授权输入监控权限...") {
                model.requestPermission()
            }
        }

        Divider()

        Button("打开主窗口") {
            openMainWindow()
        }

        Button("设置...") {
            SettingsNavigator.open()
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("退出 InputTimeline") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    private var menuStatusTitle: String {
        if !model.permissionGranted {
            return "状态：等待输入监控权限"
        }
        let base = model.isRecording ? "状态：正在记录" : "状态：已暂停"
        if let timeline = model.selectedTimeline {
            return "\(base) · \(timeline.date) (\(timeline.dayTotalCount) 条)"
        }
        return base
    }
}
