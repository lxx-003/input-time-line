import AppKit
import SwiftUI

struct TimelineCardView: View {
    let entry: TimelineDisplayItem
    let isLast: Bool
    let onCopy: () -> Void
    let onInspect: () -> Void

    @State private var isHovered = false
    @State private var didCopy = false

    private var item: TimelineItem { entry.item }
    private var theme: KindTheme { KindTheme(kind: item.kind) }

    var body: some View {
        let timeInfo = TimelineFormatters.timeLabel(for: item)
        let shouldAllowInspect = entry.isTruncated || item.text.count > 180 || item.text.contains("\n")

        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                // Left time gutter
                VStack(alignment: .trailing, spacing: 2) {
                    Text(timeInfo.clock)
                        .font(.system(size: 11.5, weight: .regular).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    if let duration = timeInfo.duration {
                        Text(duration)
                            .font(.system(size: 10.5).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 126, alignment: .trailing)
                .padding(.top, 1)

                // Semantic dot aligned with first line
                Circle()
                    .fill(theme.accentColor)
                    .frame(width: 7, height: 7)
                    .padding(.top, 5)

                // Content column (directly on canvas, zero nested boxes)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(item.kind.rawValue)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(theme.accentColor)

                        if let appName = item.appName, !appName.isEmpty {
                            Text("·")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.tertiary)

                            HStack(spacing: 4) {
                                if let nsImage = AppIconProvider.shared.icon(for: appName) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .interpolation(.high)
                                        .frame(width: 13, height: 13)
                                        .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
                                }
                                Text(appName)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 8)

                        HStack(spacing: 8) {
                            if shouldAllowInspect {
                                Button(action: onInspect) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("查看全文")
                            }

                            Button {
                                onCopy()
                                withAnimation(.easeOut(duration: 0.12)) {
                                    didCopy = true
                                }
                                Task {
                                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        didCopy = false
                                    }
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 11))
                                    if didCopy {
                                        Text("已复制")
                                            .font(.system(size: 11))
                                    }
                                }
                                .foregroundStyle(didCopy ? Color.green : Color.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("复制原文")
                        }
                        .opacity(isHovered || didCopy ? 1 : 0)
                    }

                    if item.text.isEmpty {
                        Text("（空内容）")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                    } else {
                        TimelineFormatters.formattedRichText(item.text)
                            .font(.system(size: 13))
                            .lineSpacing(4)
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if entry.isTruncated {
                        Button("展开全文（共 \(entry.originalCharacterCount) 字）") {
                            onInspect()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 2)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 11)
            .background(isHovered ? Color.primary.opacity(0.03) : Color.clear)
            .onHover { hovering in
                isHovered = hovering
            }

            if !isLast {
                Divider()
                    .padding(.leading, 171)
                    .padding(.trailing, 24)
                    .opacity(0.55)
            }
        }
    }
}

struct KindTheme {
    let kind: TimelineItemKind

    var symbolName: String {
        switch kind {
        case .keyboard: return "keyboard"
        case .copy: return "doc.on.doc"
        case .paste: return "doc.on.clipboard"
        }
    }

    var accentColor: Color {
        switch kind {
        case .keyboard: return .blue
        case .copy: return .orange
        case .paste: return .green
        }
    }
}
