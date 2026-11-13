import AppKit
import SwiftUI

extension View {
    func thinOverlayScrollbar() -> some View {
        background(ThinScrollbarConfigurator())
    }
}

private struct ThinScrollbarConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            context.coordinator.attachIfNeeded(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
    }

    @MainActor
    final class Coordinator {
        private weak var scrollView: NSScrollView?
        nonisolated(unsafe) private var observer: NSObjectProtocol?

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func attachIfNeeded(from view: NSView) {
            if scrollView == nil {
                scrollView = resolveScrollView(from: view)
            }
            applyStyle()

            if observer == nil {
                observer = NotificationCenter.default.addObserver(
                    forName: NSScroller.preferredScrollerStyleDidChangeNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in
                        self?.applyStyle()
                    }
                }
            }
        }

        func reapplyIfAttached() {
            guard scrollView != nil else { return }
            applyStyle()
        }

        private func applyStyle() {
            guard let scrollView else { return }
            if scrollView.scrollerStyle != .overlay {
                scrollView.scrollerStyle = .overlay
            }
            if !scrollView.autohidesScrollers {
                scrollView.autohidesScrollers = true
            }
            if scrollView.verticalScroller?.controlSize != .mini {
                scrollView.verticalScroller?.controlSize = .mini
            }
            if scrollView.horizontalScroller?.controlSize != .mini {
                scrollView.horizontalScroller?.controlSize = .mini
            }
        }

        private func resolveScrollView(from view: NSView) -> NSScrollView? {
            if let enclosing = view.enclosingScrollView {
                return enclosing
            }
            var current: NSView? = view.superview
            for _ in 0 ..< 4 {
                guard let container = current, !(container is NSSplitView) else { break }
                if let found = findDescendantScrollView(in: container) {
                    return found
                }
                current = container.superview
            }
            return nil
        }

        private func findDescendantScrollView(in root: NSView) -> NSScrollView? {
            for subview in root.subviews {
                if let scrollView = subview as? NSScrollView {
                    return scrollView
                }
                if let nested = findDescendantScrollView(in: subview) {
                    return nested
                }
            }
            return nil
        }
    }
}
