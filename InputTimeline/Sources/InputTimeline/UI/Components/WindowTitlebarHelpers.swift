import AppKit
import SwiftUI

// MARK: - Window Style Configurator (seamless hidden titlebar, no separator)

struct WindowStyleConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            context.coordinator.configureIfNeeded(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if context.coordinator.needsConfiguration(for: nsView) {
            DispatchQueue.main.async {
                context.coordinator.configureIfNeeded(from: nsView)
            }
        }
    }

    @MainActor
    final class Coordinator {
        private weak var configuredWindow: NSWindow?

        func needsConfiguration(for view: NSView) -> Bool {
            guard let window = view.window else { return false }
            return configuredWindow !== window
        }

        func configureIfNeeded(from view: NSView) {
            guard let window = view.window, configuredWindow !== window else { return }
            configuredWindow = window
            if !window.styleMask.contains(.fullSizeContentView) {
                window.styleMask.insert(.fullSizeContentView)
            }
            if !window.titlebarAppearsTransparent {
                window.titlebarAppearsTransparent = true
            }
            if window.titleVisibility != .hidden {
                window.titleVisibility = .hidden
            }
            if window.titlebarSeparatorStyle != .none {
                window.titlebarSeparatorStyle = .none
            }
        }
    }
}

struct WindowTitlebarDragStrip: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DragStripNSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragStripNSView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}
