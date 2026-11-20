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
        Window("Input Timeline", id: "main") {
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
            CommandGroup(replacing: .appSettings) {
                Button("偏好设置...") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                    model.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(after: .toolbar) {
                Button("刷新时间线") {
                    model.refreshAll(showFeedback: true)
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        MenuBarExtra {
            MenuBarContentView(
                openMainWindow: {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                },
                openSettings: {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                    model.openSettings()
                }
            )
            .environmentObject(model)
        } label: {
            Image(systemName: model.isRecording ? "keyboard.fill" : "keyboard")
                .help(model.isRecording ? "InputTimeline：正在记录" : "InputTimeline：已暂停")
        }
        .menuBarExtraStyle(.window)
    }
}
