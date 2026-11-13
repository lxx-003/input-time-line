import SwiftUI

struct TimelineDetailSheet: View {
    let entry: InspectedTimelineEntry
    let onCopy: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false
    @State private var showVisualControls = true

    private var theme: KindTheme { KindTheme(kind: entry.item.kind) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Label(entry.item.kind.rawValue, systemImage: theme.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(theme.accentColor.opacity(0.12), in: Capsule())

                if let appName = entry.item.appName, !appName.isEmpty {
                    HStack(spacing: 5) {
                        if let icon = AppIconProvider.shared.icon(for: appName) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 15, height: 15)
                        }
                        Text(appName)
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text(TimelineFormatters.fullTimeLabel(for: entry.item))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("共 \(entry.fullText.count) 个字符")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Spacer()

                Toggle("可视化控制符（↩ ⌫ →）", isOn: $showVisualControls)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                let displayed = showVisualControls
                    ? TimelineFormatters.formatDisplayText(entry.fullText)
                    : entry.fullText

                Text(displayed.isEmpty ? "（空内容）" : displayed)
                    .font(.system(size: 13))
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
            )

            HStack {
                Spacer()

                Button {
                    onCopy(entry.fullText)
                    withAnimation(.easeOut(duration: 0.15)) {
                        didCopy = true
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        didCopy = false
                    }
                } label: {
                    Label(didCopy ? "已复制原文" : "复制完整原文", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                }

                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 420)
    }
}
