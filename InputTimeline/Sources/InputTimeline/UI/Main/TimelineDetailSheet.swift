import SwiftUI

struct TimelineDetailSheet: View {
    let entry: InspectedTimelineEntry
    var searchQuery: String = ""
    let onCopy: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false
    @State private var showVisualControls = true

    private var theme: KindTheme { KindTheme(kind: entry.item.kind) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header row
            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: theme.symbolName)
                        .font(.system(size: 11, weight: .semibold))
                    Text(entry.item.kind.rawValue)
                        .font(PlushTheme.rounded(12, weight: .semibold))
                }
                .foregroundStyle(theme.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(theme.accentColor.opacity(0.12))
                )

                if let appName = entry.item.appName, !appName.isEmpty {
                    HStack(spacing: 5) {
                        if let icon = AppIconProvider.shared.icon(for: appName) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 15, height: 15)
                        }
                        Text(appName)
                            .font(PlushTheme.rounded(12.5, weight: .semibold))
                            .foregroundStyle(PlushTheme.ink)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(PlushTheme.surface))
                }

                Spacer()

                Text(TimelineFormatters.fullTimeLabel(for: entry.item))
                    .font(PlushTheme.rounded(11.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(PlushTheme.ink2)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(PlushCircleIconButtonStyle(diameter: 28, variant: .secondary))
                .keyboardShortcut(.cancelAction)
            }

            // Subheader controls
            HStack {
                Text("共 \(entry.fullText.count) 个字符")
                    .font(PlushTheme.rounded(12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(PlushTheme.ink2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(PlushTheme.fillStrong))

                Spacer()

                HStack(spacing: 8) {
                    Text("可视化控制符（↩ ⌫ ⇥ ←→↑↓）")
                        .font(PlushTheme.rounded(12, weight: .medium))
                        .foregroundStyle(PlushTheme.ink2)

                    PlushSwitch(isOn: $showVisualControls, size: .small)
                }
            }

            // Reading surface
            PlushScrollView {
                let displayed = showVisualControls
                    ? TimelineFormatters.formatDisplayText(entry.fullText)
                    : entry.fullText
                let placeholder = showVisualControls
                    ? TimelineFormatters.blankPlaceholder(for: entry.fullText)
                    : (entry.fullText.isEmpty ? "（空内容）" : nil)

                if let placeholder {
                    Text(placeholder)
                        .font(PlushTheme.body(13.5))
                        .foregroundStyle(PlushTheme.ink3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                } else if displayed.isEmpty {
                    Text("（空内容）")
                        .font(PlushTheme.body(13.5))
                        .foregroundStyle(PlushTheme.ink3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                } else {
                    Text(TimelineFormatters.highlightedAttributedString(displayed, query: searchQuery))
                        .font(PlushTheme.body(13.5))
                        .lineSpacing(5.5)
                        .foregroundStyle(PlushTheme.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                }
            }
            .plushCardSurface(cornerRadius: PlushTheme.Radius.card, background: PlushTheme.surface)

            // Footer actions
            HStack(spacing: 10) {
                Spacer()

                Button("关闭") {
                    dismiss()
                }
                .buttonStyle(PlushPillButtonStyle(variant: .surface, size: .md))

                Button {
                    onCopy(entry.fullText)
                    withAnimation(PlushTheme.popSpring) {
                        didCopy = true
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 1_300_000_000)
                        withAnimation(PlushTheme.fastFade) {
                            didCopy = false
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12.5, weight: .semibold))
                        Text(didCopy ? "已复制原文" : "复制完整原文")
                    }
                }
                .buttonStyle(PlushPillButtonStyle(variant: .primary, size: .md))
            }
        }
        .padding(22)
        .background(PlushTheme.panel)
        .frame(minWidth: 580, minHeight: 450)
    }
}
