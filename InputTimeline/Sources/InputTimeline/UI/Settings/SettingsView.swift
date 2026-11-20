import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        PlushScrollView {
            VStack(alignment: .leading, spacing: 12) {
                headerCard
                CaptureSettingsCard()
                PrivacyExclusionsCard()
                SystemStorageCard()
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var headerCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("偏好设置")
                    .font(PlushTheme.rounded(20, weight: .semibold))
                    .foregroundStyle(PlushTheme.ink)
                Text("所有记录均仅存于本地，可按需配置分段、隐私排除与系统集成。")
                    .font(PlushTheme.rounded(12))
                    .foregroundStyle(PlushTheme.ink2)
            }

            Spacer(minLength: 8)

            PlushStatusBadge(
                title: model.isRecording ? "采集中" : "已暂停",
                dotColor: (!model.permissionGranted || model.tapCreationFailed)
                    ? PlushTheme.warning
                    : (model.isRecording ? PlushTheme.success : PlushTheme.ink3),
                isActive: model.isRecording && model.permissionGranted && !model.tapCreationFailed
            )
        }
        .padding(18)
        .plushCardSurface(cornerRadius: PlushTheme.Radius.card, background: PlushTheme.surface)
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
