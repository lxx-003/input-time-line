import SwiftUI

struct KeyboardHeatmapCard: View {
    let insights: DailyInsights

    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredKey: KeyboardLayoutSpec.KeyDefinition?
    @State private var matrixHeight: CGFloat = 264

    private var maxKeyCount: Int {
        insights.keyCounts.values.max() ?? 0
    }

    private var heatmapSubtitle: String {
        if insights.isMultiDay && insights.hasKeyHeatmapData && insights.daysWithKeyDataCount < insights.totalDaysInRange {
            return "已统计 \(insights.daysWithKeyDataCount)/\(insights.totalDaysInRange) 天按键数据 · 过滤长按连发"
        }
        return "物理按键频次 · 过滤长按连发"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Card Header
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("键盘热力图")
                            .font(PlushTheme.rounded(15.5, weight: .semibold))
                            .foregroundStyle(PlushTheme.ink)

                        Text(heatmapSubtitle)
                            .font(PlushTheme.rounded(11, weight: .medium))
                            .foregroundStyle(PlushTheme.ink3)
                    }

                    Group {
                        if let hovered = hoveredKey {
                            hoveredKeySummary(hovered)
                        } else if insights.hasKeyHeatmapData {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("\(insights.totalKeyPresses)")
                                    .font(PlushTheme.rounded(22, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(PlushTheme.ink)
                                Text("次按键")
                                    .font(PlushTheme.rounded(12.5, weight: .medium))
                                    .foregroundStyle(PlushTheme.ink2)
                            }
                        } else {
                            Text("暂无物理按键数据")
                                .font(PlushTheme.rounded(14, weight: .medium))
                                .foregroundStyle(PlushTheme.ink2)
                        }
                    }
                    .frame(height: 27, alignment: .leading)
                }

                Spacer()

                heatLegend
            }

            // Keyboard Chassis (single GPU Canvas, zero per-key shadows)
            ZStack {
                keyboardMatrix
                    .opacity(insights.hasKeyHeatmapData ? 1.0 : 0.48)

                if !insights.hasKeyHeatmapData {
                    VStack(spacing: 6) {
                        HStack(spacing: 7) {
                            Image(systemName: "keyboard")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PlushTheme.kindKeyboard)
                            Text(insights.isMultiDay ? "该时段内未记录物理按键频次" : "该日期未记录物理按键频次")
                                .font(PlushTheme.rounded(12.5, weight: .semibold))
                                .foregroundStyle(PlushTheme.ink)
                        }
                        Text("仅记录功能更新后新采集的按键与修饰键数据")
                            .font(PlushTheme.rounded(11, weight: .medium))
                            .foregroundStyle(PlushTheme.ink2)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .plushCardSurface(
                        cornerRadius: PlushTheme.Radius.row,
                        background: PlushTheme.surfaceElevated,
                        elevated: true
                    )
                }
            }

            // Top Pressed Keys
            if !insights.topKeys.isEmpty {
                HStack(spacing: 8) {
                    Text("高频按键")
                        .font(PlushTheme.rounded(11.5, weight: .semibold))
                        .foregroundStyle(PlushTheme.ink3)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(insights.topKeys) { stat in
                                topKeyPill(stat)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
        }
        .padding(18)
        .plushCardSurface(cornerRadius: PlushTheme.Radius.card, background: PlushTheme.surface)
    }

    @ViewBuilder
    private func hoveredKeySummary(_ key: KeyboardLayoutSpec.KeyDefinition) -> some View {
        let count = key.keyCode.flatMap { insights.keyCounts[$0] } ?? 0
        let pct = insights.totalKeyPresses > 0
            ? Double(count) / Double(insights.totalKeyPresses) * 100.0
            : 0.0

        HStack(spacing: 8) {
            Text(key.fullName)
                .font(PlushTheme.rounded(15, weight: .semibold))
                .foregroundStyle(PlushTheme.ink)

            Text("·")
                .foregroundStyle(PlushTheme.ink3)

            if key.keyCode == nil {
                Text("系统保留按键")
                    .font(PlushTheme.rounded(13, weight: .medium))
                    .foregroundStyle(PlushTheme.ink3)
            } else {
                Text("\(count) 次")
                    .font(PlushTheme.rounded(15, weight: .semibold).monospacedDigit())
                    .foregroundStyle(PlushTheme.kindKeyboard)

                Text(String(format: "(%.1f%%)", pct))
                    .font(PlushTheme.rounded(12, weight: .medium).monospacedDigit())
                    .foregroundStyle(PlushTheme.ink2)
            }
        }
    }

    private var heatLegend: some View {
        HStack(spacing: 5) {
            Text("少")
                .font(PlushTheme.rounded(10.5, weight: .medium))
                .foregroundStyle(PlushTheme.ink3)

            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(heatBackground(intensity: level, isReserved: false))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .strokeBorder(PlushTheme.line.opacity(level == 0 ? 0.8 : 0.2), lineWidth: 0.6)
                    )
                    .frame(width: 13, height: 13)
            }

            Text("多")
                .font(PlushTheme.rounded(10.5, weight: .medium))
                .foregroundStyle(PlushTheme.ink3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(PlushTheme.fill))
    }

    private struct KeySlot {
        let key: KeyboardLayoutSpec.KeyDefinition
        let rect: CGRect
        let cornerRadius: CGFloat
        let isCompact: Bool
    }

    private struct KeyboardGeometry {
        let slots: [KeySlot]
        let totalHeight: CGFloat

        init(containerWidth: CGFloat) {
            let padding: CGFloat = 12
            let innerWidth = max(440, containerWidth - padding * 2)
            let gap = max(4, min(7, innerWidth * 0.0072))
            let unit = (innerWidth - 13 * gap) / KeyboardLayoutSpec.totalUnitsPerRow
            let stdH = max(30, min(48, unit * 0.90))
            let fnH = max(24, min(36, unit * 0.66))
            let arrowHalfH = (stdH - gap * 0.75) / 2.0
            let cornerR = max(5.5, min(9, unit * 0.16))
            let compactCornerR = max(4.5, cornerR * 0.8)

            var built: [KeySlot] = []
            built.reserveCapacity(78)

            var y: CGFloat = padding

            // Row 1: Function Keys
            var x: CGFloat = padding
            for (index, key) in KeyboardLayoutSpec.row1.enumerated() {
                let w: CGFloat = (index == 0 || index == 13) ? unit * 1.3 : unit
                built.append(KeySlot(key: key, rect: CGRect(x: x, y: y, width: w, height: fnH), cornerRadius: cornerR, isCompact: true))
                x += w + gap
            }
            y += fnH + gap

            // Row 2: Number Row
            x = padding
            for key in KeyboardLayoutSpec.row2 {
                let w = unit * key.unitWidth
                built.append(KeySlot(key: key, rect: CGRect(x: x, y: y, width: w, height: stdH), cornerRadius: cornerR, isCompact: false))
                x += w + gap
            }
            y += stdH + gap

            // Row 3: QWERTY Row
            x = padding
            for key in KeyboardLayoutSpec.row3 {
                let w = unit * key.unitWidth
                built.append(KeySlot(key: key, rect: CGRect(x: x, y: y, width: w, height: stdH), cornerRadius: cornerR, isCompact: false))
                x += w + gap
            }
            y += stdH + gap

            // Row 4: ASDF Row
            x = padding
            for (index, key) in KeyboardLayoutSpec.row4.enumerated() {
                let extra: CGFloat = (index == 0 || index == KeyboardLayoutSpec.row4.count - 1) ? gap * 0.5 : 0
                let w = unit * key.unitWidth + extra
                built.append(KeySlot(key: key, rect: CGRect(x: x, y: y, width: w, height: stdH), cornerRadius: cornerR, isCompact: false))
                x += w + gap
            }
            y += stdH + gap

            // Row 5: ZXCV Row
            x = padding
            for (index, key) in KeyboardLayoutSpec.row5.enumerated() {
                let extra: CGFloat = (index == 0 || index == KeyboardLayoutSpec.row5.count - 1) ? gap : 0
                let w = unit * key.unitWidth + extra
                built.append(KeySlot(key: key, rect: CGRect(x: x, y: y, width: w, height: stdH), cornerRadius: cornerR, isCompact: false))
                x += w + gap
            }
            y += stdH + gap

            // Row 6: Modifiers + Space + Inverted-T Arrows
            x = padding
            for key in KeyboardLayoutSpec.row6Left {
                let extra: CGFloat = key.keyCode == 49 ? gap * 4.0 : 0
                let w = unit * key.unitWidth + extra
                built.append(KeySlot(key: key, rect: CGRect(x: x, y: y, width: w, height: stdH), cornerRadius: cornerR, isCompact: false))
                x += w + gap
            }

            // Left Arrow
            built.append(KeySlot(
                key: KeyboardLayoutSpec.arrowLeft,
                rect: CGRect(x: x, y: y + stdH - arrowHalfH, width: unit, height: arrowHalfH),
                cornerRadius: compactCornerR,
                isCompact: true
            ))
            x += unit + gap

            // Up & Down Arrows
            built.append(KeySlot(
                key: KeyboardLayoutSpec.arrowUp,
                rect: CGRect(x: x, y: y, width: unit, height: arrowHalfH),
                cornerRadius: compactCornerR,
                isCompact: true
            ))
            built.append(KeySlot(
                key: KeyboardLayoutSpec.arrowDown,
                rect: CGRect(x: x, y: y + arrowHalfH + gap * 0.75, width: unit, height: arrowHalfH),
                cornerRadius: compactCornerR,
                isCompact: true
            ))
            x += unit + gap

            // Right Arrow
            built.append(KeySlot(
                key: KeyboardLayoutSpec.arrowRight,
                rect: CGRect(x: x, y: y + stdH - arrowHalfH, width: unit, height: arrowHalfH),
                cornerRadius: compactCornerR,
                isCompact: true
            ))

            self.slots = built
            self.totalHeight = y + stdH + padding
        }
    }

    private var keyboardMatrix: some View {
        GeometryReader { proxy in
            let geometry = KeyboardGeometry(containerWidth: proxy.size.width)

            Canvas { context, size in
                let chassisRect = CGRect(origin: .zero, size: size)
                let chassisPath = Path(roundedRect: chassisRect, cornerRadius: PlushTheme.Radius.row, style: .continuous)
                context.fill(chassisPath, with: .color(PlushTheme.panel))
                context.stroke(chassisPath, with: .color(PlushTheme.line), lineWidth: 0.75)

                for slot in geometry.slots {
                    drawKeyCap(in: &context, slot: slot)
                }
            }
            .frame(width: proxy.size.width, height: geometry.totalHeight)
            .contentShape(RoundedRectangle(cornerRadius: PlushTheme.Radius.row, style: .continuous))
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let found = geometry.slots.first { $0.rect.contains(location) }?.key
                    if hoveredKey?.id != found?.id {
                        hoveredKey = found
                    }
                case .ended:
                    if hoveredKey != nil {
                        hoveredKey = nil
                    }
                }
            }
            .onAppear {
                if abs(matrixHeight - geometry.totalHeight) > 0.5 {
                    matrixHeight = geometry.totalHeight
                }
            }
            .onChange(of: proxy.size.width) { newWidth in
                let updated = KeyboardGeometry(containerWidth: newWidth).totalHeight
                if abs(matrixHeight - updated) > 0.5 {
                    matrixHeight = updated
                }
            }
        }
        .frame(height: matrixHeight)
    }

    private func drawKeyCap(in context: inout GraphicsContext, slot: KeySlot) {
        let key = slot.key
        let count = key.keyCode.flatMap { insights.keyCounts[$0] } ?? 0
        let intensity = heatIntensity(for: count)
        let isHovered = hoveredKey?.id == key.id
        let isReserved = key.keyCode == nil
        let bg = heatBackground(intensity: intensity, isReserved: isReserved)
        let fg = heatForeground(intensity: intensity, isReserved: isReserved)

        let drawRect = isHovered ? slot.rect.insetBy(dx: -1.0, dy: -1.0) : slot.rect
        let capPath = Path(roundedRect: drawRect, cornerRadius: slot.cornerRadius, style: .continuous)

        context.fill(capPath, with: .color(bg))

        let borderColor: Color = isHovered
            ? PlushTheme.selectA
            : PlushTheme.line.opacity(intensity > 0.15 ? 0.22 : 0.78)
        context.stroke(capPath, with: .color(borderColor), lineWidth: isHovered ? 1.6 : 0.8)

        let center = CGPoint(x: drawRect.midX, y: drawRect.midY)

        if let secondary = key.secondaryLabel, !slot.isCompact {
            let topText = Text(secondary)
                .font(PlushTheme.rounded(9.5, weight: .medium))
                .foregroundColor(fg.opacity(0.68))
            let bottomText = Text(key.label)
                .font(PlushTheme.rounded(11.5, weight: .semibold))
                .foregroundColor(fg)
            context.draw(topText, at: CGPoint(x: center.x, y: center.y - 6.5), anchor: .center)
            context.draw(bottomText, at: CGPoint(x: center.x, y: center.y + 6.0), anchor: .center)
        } else {
            let fontSize: CGFloat = slot.isCompact ? 10.5 : (drawRect.width < 32 ? 10.5 : 12)
            let labelText = Text(key.label)
                .font(PlushTheme.rounded(fontSize, weight: .semibold))
                .foregroundColor(fg)
            context.draw(labelText, at: center, anchor: .center)
        }
    }

    private func topKeyPill(_ stat: KeyHeatmapStat) -> some View {
        let intensity = heatIntensity(for: stat.count)
        return HStack(spacing: 6) {
            Circle()
                .fill(heatBackground(intensity: max(0.35, intensity), isReserved: false))
                .frame(width: 7, height: 7)

            Text(stat.label)
                .font(PlushTheme.rounded(11.5, weight: .semibold))
                .foregroundStyle(PlushTheme.ink)

            Text("\(stat.count)")
                .font(PlushTheme.rounded(11, weight: .semibold).monospacedDigit())
                .foregroundStyle(PlushTheme.ink2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(PlushTheme.fill))
    }

    private func heatIntensity(for count: Int) -> Double {
        guard count > 0, maxKeyCount > 0 else { return 0 }
        let ratio = Double(count) / Double(maxKeyCount)
        return min(1.0, max(0.08, pow(ratio, 0.55)))
    }

    private func heatBackground(intensity: Double, isReserved: Bool) -> Color {
        if isReserved {
            return PlushTheme.fill.opacity(0.6)
        }
        if intensity <= 0.001 {
            return colorScheme == .dark ? PlushTheme.surfaceElevated : PlushTheme.surface
        }

        if colorScheme == .dark {
            let r = lerp(0.14, 0.24, intensity)
            let g = lerp(0.22, 0.54, intensity)
            let b = lerp(0.36, 0.98, intensity)
            return Color(red: r, green: g, blue: b)
        } else {
            let r = lerp(0.87, 0.145, intensity)
            let g = lerp(0.92, 0.388, intensity)
            let b = lerp(0.99, 0.922, intensity)
            return Color(red: r, green: g, blue: b)
        }
    }

    private func heatForeground(intensity: Double, isReserved: Bool) -> Color {
        if isReserved {
            return PlushTheme.ink3
        }
        let threshold = colorScheme == .dark ? 0.38 : 0.48
        return intensity >= threshold ? Color.white : PlushTheme.ink
    }

    private func lerp(_ start: Double, _ end: Double, _ t: Double) -> Double {
        start + (end - start) * t
    }
}
