import AppKit
import SwiftUI

// MARK: - Window Style Configurator (seamless hidden titlebar, no separator)

struct WindowStyleConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configureWindow(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindow(from: nsView)
        }
    }

    @MainActor
    private func configureWindow(from view: NSView) {
        guard let window = view.window else { return }
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
