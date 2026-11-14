import AppKit
import SwiftUI

struct TimelineCardView: View {
    let entry: TimelineDisplayItem
    let searchQuery: String
    let activeAppFilter: String?
    let onCopy: () -> Void
    let onInspect: () -> Void
    let onToggleAppFilter: ((String) -> Void)?

    @State private var isHovered = false
    @State private var didCopy = false

    private var item: TimelineItem { entry.item }
    private var theme: KindTheme { KindTheme(kind: item.kind) }

    var body: some View {
        let timeInfo = TimelineFormatters.timeLabel(for: item)
        let shouldAllowInspect = entry.isTruncated || item.text.count > 160 || item.text.contains("\n")

        HStack(alignment: .top, spacing: 14) {
            // Left time gutter
            VStack(alignment: .trailing, spacing: 4) {
                Text(timeInfo.clock)
                    .font(PlushTheme.rounded(11.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(isHovered ? PlushTheme.ink : PlushTheme.ink2)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                if let duration = timeInfo.duration {
                    Text(duration)
                        .font(PlushTheme.rounded(10, weight: .semibold).monospacedDigit())
                        .foregroundStyle(PlushTheme.ink2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(PlushTheme.fill))
                }
            }
            .frame(width: 112, alignment: .trailing)
            .padding(.top, 2)

            // Semantic timeline dot
            Circle()
                .fill(theme.accentColor)
                .frame(width: 7, height: 7)
                .padding(.top, 5)

            // Content column
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    // Kind badge pill
                    HStack(spacing: 5) {
                        Image(systemName: theme.symbolName)
                            .font(.system(size: 10, weight: .semibold))
                        Text(item.kind.rawValue)
                            .font(PlushTheme.rounded(11, weight: .semibold))
                    }
                    .foregroundStyle(theme.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(theme.accentColor.opacity(0.11)))

                    // App source chip (clickable to filter by app)
                    if let appName = item.appName, !appName.isEmpty {
                        let isFilteredApp = activeAppFilter?.caseInsensitiveCompare(appName) == .orderedSame
                        Button {
                            onToggleAppFilter?(appName)
                        } label: {
                            HStack(spacing: 5) {
                                if let nsImage = AppIconProvider.shared.icon(for: appName) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .interpolation(.high)
                                        .frame(width: 13, height: 13)
                                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                                }
                                Text(appName)
                                    .font(PlushTheme.rounded(11.5, weight: .medium))
                                    .foregroundStyle(isFilteredApp ? PlushTheme.onSelect : PlushTheme.ink2)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(isFilteredApp ? AnyShapeStyle(PlushTheme.selectGradient) : AnyShapeStyle(PlushTheme.fill))
                            )
                        }
                        .buttonStyle(.plain)
                        .help(isFilteredApp ? "取消按 \(appName) 筛选" : "仅查看来自 \(appName) 的记录")
                    }

                    Spacer(minLength: 8)

                    // Plush action buttons (rendered only on hover/copy to keep scrolling fast)
                    if isHovered || didCopy {
                        HStack(spacing: 6) {
                            if shouldAllowInspect {
                                Button(action: onInspect) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 10.5, weight: .semibold))
                                }
                                .buttonStyle(PlushCircleIconButtonStyle(diameter: 26, variant: .secondary))
                                .help("查看全文")
                            }

                            Button {
                                onCopy()
                                withAnimation(PlushTheme.popSpring) {
                                    didCopy = true
                                }
                                Task {
                                    try? await Task.sleep(nanoseconds: 1_400_000_000)
                                    withAnimation(PlushTheme.fastFade) {
                                        didCopy = false
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 10.5, weight: .semibold))
                                    if didCopy {
                                        Text("已复制")
                                            .font(PlushTheme.rounded(11, weight: .semibold))
                                    }
                                }
                                .foregroundStyle(didCopy ? Color.white : PlushTheme.ink)
                                .padding(.horizontal, didCopy ? 9 : 0)
                                .frame(minWidth: 26, minHeight: 26)
                                .background(
                                    Capsule()
                                        .fill(didCopy ? PlushTheme.success : PlushTheme.fill)
                                )
                            }
                            .buttonStyle(.plain)
                            .help("复制原文")
                        }
                    }
                }
                .frame(minHeight: 26)

                if let placeholder = TimelineFormatters.blankPlaceholder(for: item.text) {
                    Text(placeholder)
                        .font(PlushTheme.body(13))
                        .foregroundStyle(PlushTheme.ink3)
                } else {
                    TimelineFormatters.formattedRichText(item.text, highlightQuery: searchQuery)
                        .font(PlushTheme.body(13))
                        .lineSpacing(4.5)
                        .foregroundStyle(PlushTheme.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if entry.isTruncated {
                    Button(action: onInspect) {
                        HStack(spacing: 4) {
                            Text("展开全文")
                            Text("· \(entry.originalCharacterCount) 字")
                                .foregroundStyle(PlushTheme.ink2)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9.5, weight: .bold))
                        }
                        .font(PlushTheme.rounded(11.5, weight: .semibold))
                        .foregroundStyle(PlushTheme.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(PlushTheme.fill))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: PlushTheme.Radius.row, style: .continuous)
                .fill(isHovered ? PlushTheme.surfaceElevated : PlushTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: PlushTheme.Radius.row, style: .continuous)
                        .strokeBorder(
                            isHovered ? PlushTheme.line : PlushTheme.line.opacity(0.45),
                            lineWidth: 0.75
                        )
                )
        )
        .onHover { hovering in
            if isHovered != hovering {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button {
                onCopy()
            } label: {
                Label("复制原文", systemImage: "doc.on.doc")
            }

            if shouldAllowInspect {
                Button {
                    onInspect()
                } label: {
                    Label("查看全文", systemImage: "arrow.up.left.and.arrow.down.right")
                }
            }

            if let appName = item.appName, !appName.isEmpty {
                Divider()
                Button {
                    onToggleAppFilter?(appName)
                } label: {
                    Label("筛选应用「\(appName)」", systemImage: "line.3.horizontal.decrease.circle")
                }
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
        case .keyboard: return PlushTheme.kindKeyboard
        case .copy: return PlushTheme.kindCopy
        case .paste: return PlushTheme.kindPaste
        }
    }
}
