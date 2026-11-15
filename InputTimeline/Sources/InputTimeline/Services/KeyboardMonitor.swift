import ApplicationServices
import AppKit
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

    init(onKeyboardText: @escaping @Sendable (String, String?, Date) -> Void,
         onClipboardShortcut: @escaping @Sendable (ClipboardAction, String?, Date) -> Void,
         onKeyPress: @escaping @Sendable (Int, String?, Date) -> Void = { _, _, _ in }) {
        self.callbackState = CallbackState(
            onKeyboardText: onKeyboardText,
            onClipboardShortcut: onClipboardShortcut,
            onKeyPress: onKeyPress
        )
    }

    deinit {
        stop()
    }

    func start() -> StartResult {
        guard eventTap == nil else { return .alreadyRunning }
        guard PermissionHelper.inputMonitoringGranted() else {
            return .permissionDenied
        }

        let mask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue))
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
                guard (type == .keyDown || type == .flagsChanged), let refcon else {
                    return Unmanaged.passUnretained(event)
                }

                let state = Unmanaged<CallbackState>.fromOpaque(refcon).takeUnretainedValue()
                state.handle(event: event, type: type)
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
    private let onKeyboardText: @Sendable (String, String?, Date) -> Void
    private let onClipboardShortcut: @Sendable (ClipboardAction, String?, Date) -> Void
    private let onKeyPress: @Sendable (Int, String?, Date) -> Void
    private var previousFlags = CGEventFlags()

    init(onKeyboardText: @escaping @Sendable (String, String?, Date) -> Void,
         onClipboardShortcut: @escaping @Sendable (ClipboardAction, String?, Date) -> Void,
         onKeyPress: @escaping @Sendable (Int, String?, Date) -> Void) {
        self.onKeyboardText = onKeyboardText
        self.onClipboardShortcut = onClipboardShortcut
        self.onKeyPress = onKeyPress
    }

    func handle(event: CGEvent, type: CGEventType) {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let timestamp = Date()
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName

        if type == .flagsChanged {
            let currentFlags = event.flags
            let pressed = isModifierPress(keyCode: keyCode, previous: previousFlags, current: currentFlags)
            previousFlags = currentFlags
            if pressed {
                onKeyPress(keyCode, appName, timestamp)
            }
            return
        }

        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        if !isRepeat {
            onKeyPress(keyCode, appName, timestamp)
        }

        let flags = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])

        if flags.contains(.maskCommand), !flags.contains(.maskControl), !flags.contains(.maskAlternate) {
            if keyCode == 8 {
                onClipboardShortcut(.copy, appName, timestamp)
                return
            }
            if keyCode == 9 {
                onClipboardShortcut(.paste, appName, timestamp)
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

        onKeyboardText(text, appName, timestamp)
    }

    private func isModifierPress(keyCode: Int, previous: CGEventFlags, current: CGEventFlags) -> Bool {
        switch keyCode {
        case 57: // Caps Lock toggles alphaShift on press
            return previous.contains(.maskAlphaShift) != current.contains(.maskAlphaShift)
        case 63: // Fn / Globe
            return !previous.contains(.maskSecondaryFn) && current.contains(.maskSecondaryFn)
        case 54: // Right Command (NX_DEVICERCMDKEYMASK = 0x0010)
            return checkModifierTransition(deviceMask: 0x0010, genericMask: .maskCommand, previous: previous, current: current)
        case 55: // Left Command (NX_DEVICELCMDKEYMASK = 0x0008)
            return checkModifierTransition(deviceMask: 0x0008, genericMask: .maskCommand, previous: previous, current: current)
        case 56: // Left Shift (NX_DEVICELSHIFTKEYMASK = 0x0002)
            return checkModifierTransition(deviceMask: 0x0002, genericMask: .maskShift, previous: previous, current: current)
        case 60: // Right Shift (NX_DEVICERSHIFTKEYMASK = 0x0004)
            return checkModifierTransition(deviceMask: 0x0004, genericMask: .maskShift, previous: previous, current: current)
        case 58: // Left Option (NX_DEVICELALTKEYMASK = 0x0020)
            return checkModifierTransition(deviceMask: 0x0020, genericMask: .maskAlternate, previous: previous, current: current)
        case 61: // Right Option (NX_DEVICERALTKEYMASK = 0x0040)
            return checkModifierTransition(deviceMask: 0x0040, genericMask: .maskAlternate, previous: previous, current: current)
        case 59: // Left Control (NX_DEVICELCTLKEYMASK = 0x0001)
            return checkModifierTransition(deviceMask: 0x0001, genericMask: .maskControl, previous: previous, current: current)
        case 62: // Right Control (NX_DEVICERCTLKEYMASK = 0x2000)
            return checkModifierTransition(deviceMask: 0x2000, genericMask: .maskControl, previous: previous, current: current)
        default:
            return false
        }
    }

    private func checkModifierTransition(
        deviceMask: UInt64,
        genericMask: CGEventFlags,
        previous: CGEventFlags,
        current: CGEventFlags
    ) -> Bool {
        let allDeviceBits: UInt64 = 0x207F
        if (current.rawValue & allDeviceBits) != 0 || (previous.rawValue & allDeviceBits) != 0 {
            return (previous.rawValue & deviceMask) == 0 && (current.rawValue & deviceMask) != 0
        }
        return !previous.contains(genericMask) && current.contains(genericMask)
    }
}
