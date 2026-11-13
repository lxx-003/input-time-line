import AppKit

// MARK: - 3pt Borderless Overlay Scroller (no slot background, no border line)

final class ThinOverlayScroller: NSScroller {
    private var isHovered = false
    private var hoverTrackingArea: NSTrackingArea?

    override class var isCompatibleWithOverlayScrollers: Bool { true }

    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = nil
        layer?.borderWidth = 0
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = nil
        layer?.borderWidth = 0
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        needsDisplay = true
    }

    // Never draw the slot track or border
    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {}

    override func draw(_ dirtyRect: NSRect) {
        drawKnob()
    }

    override func drawKnob() {
        let knobRect = rect(for: .knob)
        guard !knobRect.isEmpty else { return }

        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let baseAlpha: CGFloat = isHovered ? 0.44 : 0.24
        let thumbColor = isDark
            ? NSColor.white.withAlphaComponent(baseAlpha)
            : NSColor(srgbRed: 0.08, green: 0.08, blue: 0.09, alpha: baseAlpha)

        let thickness: CGFloat = 3.0
        let edgeInset: CGFloat = 2.5

        let paintedRect: NSRect
        if bounds.height >= bounds.width {
            // Vertical scroller: 3pt painted thumb aligned near right edge
            let x = max(0, bounds.maxX - thickness - edgeInset)
            let y = knobRect.minY + 2
            let h = max(12, knobRect.height - 4)
            paintedRect = NSRect(x: x, y: y, width: thickness, height: h)
        } else {
            // Horizontal scroller: 3pt painted thumb aligned near bottom edge
            let y = max(0, bounds.maxY - thickness - edgeInset)
            let x = knobRect.minX + 2
            let w = max(12, knobRect.width - 4)
            paintedRect = NSRect(x: x, y: y, width: w, height: thickness)
        }

        thumbColor.setFill()
        NSBezierPath(roundedRect: paintedRect, xRadius: thickness / 2, yRadius: thickness / 2).fill()
    }
}
