import ApplicationServices
import Foundation

enum ClipboardAction {
    case copy
    case paste
}

final class KeyboardMonitor {
    enum StartResult {
        case started
        case alreadyRunning
        case permissionDenied
        case tapCreateFailed
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let callbackState: CallbackState
    private var callbackStatePointer: UnsafeMutableRawPointer?

    init(onKeyboardText: @escaping @Sendable (String, Date) -> Void,
         onClipboardShortcut: @escaping @Sendable (ClipboardAction, Date) -> Void) {
        self.callbackState = CallbackState(onKeyboardText: onKeyboardText, onClipboardShortcut: onClipboardShortcut)
    }

    deinit {
        stop()
    }

    func start() -> StartResult {
        guard eventTap == nil else { return .alreadyRunning }
        guard PermissionHelper.inputMonitoringGranted() else {
            return .permissionDenied
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let userInfo = Unmanaged.passRetained(callbackState).toOpaque()
        callbackStatePointer = userInfo

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            // Passive monitoring should use a listen-only tap so the app only
            // requires Input Monitoring and does not need Accessibility-style
            // privileges to modify or suppress events.
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard type == .keyDown, let refcon else {
                    return Unmanaged.passUnretained(event)
                }

                let state = Unmanaged<CallbackState>.fromOpaque(refcon).takeUnretainedValue()
                state.handle(event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: userInfo
        ) else {
            Unmanaged<CallbackState>.fromOpaque(userInfo).release()
            callbackStatePointer = nil
            return .tapCreateFailed
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        return .started
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let callbackStatePointer {
            Unmanaged<CallbackState>.fromOpaque(callbackStatePointer).release()
        }
        runLoopSource = nil
        eventTap = nil
        callbackStatePointer = nil
    }
}

private final class CallbackState {
    private let onKeyboardText: @Sendable (String, Date) -> Void
    private let onClipboardShortcut: @Sendable (ClipboardAction, Date) -> Void

    init(onKeyboardText: @escaping @Sendable (String, Date) -> Void,
         onClipboardShortcut: @escaping @Sendable (ClipboardAction, Date) -> Void) {
        self.onKeyboardText = onKeyboardText
        self.onClipboardShortcut = onClipboardShortcut
    }

    func handle(event: CGEvent) {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])
        let timestamp = Date()

        if flags.contains(.maskCommand), !flags.contains(.maskControl), !flags.contains(.maskAlternate) {
            if keyCode == 8 {
                onClipboardShortcut(.copy, timestamp)
                return
            }
            if keyCode == 9 {
                onClipboardShortcut(.paste, timestamp)
                return
            }
        }

        guard !flags.contains(.maskCommand), !flags.contains(.maskControl), !flags.contains(.maskAlternate) else {
            return
        }

        let maxLength = 8
        var buffer = [UniChar](repeating: 0, count: maxLength)
        var actualLength: Int = 0
        event.keyboardGetUnicodeString(maxStringLength: maxLength, actualStringLength: &actualLength, unicodeString: &buffer)

        guard actualLength > 0 else { return }

        let text = String(utf16CodeUnits: buffer, count: actualLength)
            .replacingOccurrences(of: "\u{7F}", with: "")
        guard !text.isEmpty else { return }

        onKeyboardText(text, timestamp)
    }
}
