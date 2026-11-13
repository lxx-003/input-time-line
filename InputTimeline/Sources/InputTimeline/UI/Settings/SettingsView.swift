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
        PlushScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("偏好设置")
                            .font(PlushTheme.rounded(20, weight: .semibold))
                            .foregroundStyle(PlushTheme.ink)
                        Text("所有记录均仅存于本地，可按需配置分段、隐私排除与系统集成。")
                            .font(PlushTheme.rounded(12))
                            .foregroundStyle(PlushTheme.ink2)
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)

                CaptureSettingsCard()
                PrivacyExclusionsCard()
                SystemStorageCard()
            }
            .padding(20)
        }
        .background(PlushTheme.panel)
        .frame(width: 560, height: 560)
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PlushTheme.ink2)
                Text(title)
                    .font(PlushTheme.rounded(13.5, weight: .semibold))
                    .foregroundStyle(PlushTheme.ink)
            }

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
        }
        .padding(16)
        .plushCardSurface(cornerRadius: PlushTheme.Radius.card, background: PlushTheme.surface)
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PlushTheme.rounded(13, weight: .semibold))
                    .foregroundStyle(PlushTheme.ink)
                Text(subtitle)
                    .font(PlushTheme.rounded(11.5))
                    .foregroundStyle(PlushTheme.ink2)
            }
            Spacer()
            control()
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppModel.previewSample())
    }
}
