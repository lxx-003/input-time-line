import SwiftUI

struct FilteredEmptyStateView: View {
    @EnvironmentObject private var model: AppModel
    let dayTotalCount: Int

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(PlushTheme.fill)
                        .frame(width: 56, height: 56)
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(PlushTheme.ink2)
                }

                Text(dayTotalCount == 0 ? "当天暂无记录" : "没有匹配的记录")
                    .font(PlushTheme.rounded(16, weight: .semibold))
                    .foregroundStyle(PlushTheme.ink)

                if dayTotalCount > 0 {
                    Text("尝试更换搜索关键词、切换事件类型或清除应用筛选。")
                        .font(PlushTheme.rounded(13))
                        .foregroundStyle(PlushTheme.ink2)

                    Button("清除全部筛选") {
                        withAnimation(PlushTheme.spring) {
                            model.clearFilters()
                        }
                    }
                    .buttonStyle(PlushPillButtonStyle(variant: .primary, size: .sm))
                    .padding(.top, 4)
                }
            }
            .padding(28)
            .plushCardSurface(cornerRadius: PlushTheme.Radius.panel, background: PlushTheme.surface)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

struct PermissionOnboardingView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(PlushTheme.warning.opacity(0.16))
                            .frame(width: 44, height: 44)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(PlushTheme.warning)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("开启输入监控权限")
                            .font(PlushTheme.rounded(18, weight: .semibold))
                            .foregroundStyle(PlushTheme.ink)
                        Text("只需三步即可本地记录输入与剪贴板时间线")
                            .font(PlushTheme.rounded(12.5))
                            .foregroundStyle(PlushTheme.ink2)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    onboardingStep(number: 1, text: "点击下方按钮，打开「系统设置 → 隐私与安全性 → 输入监控」", active: true)
                    onboardingStep(number: 2, text: "找到并勾选允许 InputTimeline（若刚重编译请先移除旧条目）", active: false)
                    onboardingStep(number: 3, text: "切回应用即可自动开始采集，所有数据仅保存于本机", active: false)
                }

                HStack(spacing: 10) {
                    Button("前往系统设置授权") {
                        model.requestPermission()
                    }
                    .buttonStyle(PlushPillButtonStyle(variant: .primary, size: .md))

                    Button("重新检查") {
                        model.refreshAll(showFeedback: true)
                    }
                    .buttonStyle(PlushPillButtonStyle(variant: .secondary, size: .md))
                }
            }
            .padding(26)
            .frame(maxWidth: 480)
            .plushCardSurface(cornerRadius: PlushTheme.Radius.panel, background: PlushTheme.surface)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private func onboardingStep(number: Int, text: String, active: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(active ? PlushTheme.accent : PlushTheme.fillStrong)
                    .frame(width: 24, height: 24)
                Text("\(number)")
                    .font(PlushTheme.rounded(12, weight: .semibold))
                    .foregroundStyle(active ? PlushTheme.onAccent : PlushTheme.ink2)
            }

            Text(text)
                .font(PlushTheme.rounded(12.5, weight: .medium))
                .foregroundStyle(PlushTheme.ink)
        }
    }
}

struct NoTimelineEmptyStateView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(model.isRecording ? PlushTheme.selectPlate : PlushTheme.fill)
                        .frame(width: 58, height: 58)
                    Image(systemName: model.isRecording ? "keyboard.fill" : "pause.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(model.isRecording ? PlushTheme.selectA : PlushTheme.ink2)
                }

                Text("暂无时间线记录")
                    .font(PlushTheme.rounded(17, weight: .semibold))
                    .foregroundStyle(PlushTheme.ink)

                Text(model.isRecording
                     ? "在其他应用打字或复制粘贴后，记录会自动出现在这里。"
                     : "当前记录已暂停，开启左下角开关即可开始采集。")
                    .font(PlushTheme.rounded(13))
                    .foregroundStyle(PlushTheme.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
            .padding(30)
            .plushCardSurface(cornerRadius: PlushTheme.Radius.panel, background: PlushTheme.surface)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
