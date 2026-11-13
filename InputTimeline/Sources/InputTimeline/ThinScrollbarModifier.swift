import AppKit
import SwiftUI

/// A ScrollView wrapped with a 3pt borderless, slot-free overlay scroller.
struct PlushScrollView<Content: View>: View {
    let showsIndicators: Bool
    @ViewBuilder let content: () -> Content

    init(showsIndicators: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.showsIndicators = showsIndicators
        self.content = content
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: showsIndicators) {
            content()
                .background(EnclosingScrollViewAnchor())
        }
    }
}

extension View {
    /// Attach directly on the content *inside* a ScrollView (or on a ScrollView as fallback).
    func thinOverlayScrollbar() -> some View {
        background(EnclosingScrollViewAnchor())
    }
}

private struct EnclosingScrollViewAnchor: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> AnchorNSView {
        let view = AnchorNSView()
        view.onMovedToWindow = { [weak coordinator = context.coordinator, weak view] in
            guard let view else { return }
            coordinator?.attach(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: AnchorNSView, context: Context) {
        if nsView.window != nil {
            context.coordinator.attach(from: nsView)
        }
    }

    final class AnchorNSView: NSView {
        var onMovedToWindow: (() -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in
                self?.onMovedToWindow?()
            }
        }
    }

    @MainActor
    final class Coordinator {
        private weak var scrollView: NSScrollView?
        nonisolated(unsafe) private var styleObserver: NSObjectProtocol?

        deinit {
            if let styleObserver {
                NotificationCenter.default.removeObserver(styleObserver)
            }
        }

        func attach(from view: NSView) {
            let resolved = view.enclosingScrollView ?? fallbackResolveScrollView(from: view)
            guard let resolved else { return }

            if scrollView !== resolved {
                scrollView = resolved
            }
            applyThinStyle(to: resolved)

            if styleObserver == nil {
                styleObserver = NotificationCenter.default.addObserver(
                    forName: NSScroller.preferredScrollerStyleDidChangeNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in
                        guard let self, let scrollView = self.scrollView else { return }
                        self.applyThinStyle(to: scrollView)
                    }
                }
            }
        }

        private func applyThinStyle(to scrollView: NSScrollView) {
            if scrollView.borderType != .noBorder {
                scrollView.borderType = .noBorder
            }
            if scrollView.drawsBackground {
                scrollView.drawsBackground = false
            }
            if scrollView.scrollerStyle != .overlay {
                scrollView.scrollerStyle = .overlay
            }
            if !scrollView.autohidesScrollers {
                scrollView.autohidesScrollers = true
            }

            if scrollView.hasVerticalScroller, !(scrollView.verticalScroller is ThinOverlayScroller) {
                let scroller = ThinOverlayScroller()
                scroller.scrollerStyle = .overlay
                scroller.controlSize = .mini
                scrollView.verticalScroller = scroller
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }

            if scrollView.hasHorizontalScroller, !(scrollView.horizontalScroller is ThinOverlayScroller) {
                let scroller = ThinOverlayScroller()
                scroller.scrollerStyle = .overlay
                scroller.controlSize = .mini
                scrollView.horizontalScroller = scroller
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }

        private func fallbackResolveScrollView(from view: NSView) -> NSScrollView? {
            var current: NSView? = view.superview
            for _ in 0 ..< 5 {
                guard let container = current, !(container is NSSplitView) else { break }
                if let found = container.subviews.compactMap({ $0 as? NSScrollView }).first {
                    return found
                }
                current = container.superview
            }
            return nil
        }
    }
}

// MARK: - 3pt Borderless Overlay Scroller (no slot background, no border line)

private final class ThinOverlayScroller: NSScroller {
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
