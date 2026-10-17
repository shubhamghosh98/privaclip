import Foundation
import AppKit
import Carbon
import os

/// Registers and listens for global keyboard shortcuts using the Carbon Event Manager.
public final class HotkeyManager: @unchecked Sendable {
    public static let shared = HotkeyManager()

    private let logger = Logger(subsystem: "com.privaclip.app", category: "hotkey")
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var actionHandler: (@Sendable () -> Void)?

    private static let signature: OSType = {
        let chars = "PrvC".utf8
        var val: OSType = 0
        for c in chars {
            val = (val << 8) + OSType(c)
        }
        return val
    }()

    private static var eventSpec = EventTypeSpec(
        eventClass: OSType(kEventClassKeyboard),
        eventKind: UInt32(kEventHotKeyPressed)
    )

    private static let eventHandlerCallback: EventHandlerUPP = { _, eventRef, _ in
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        if status == noErr && hotKeyID.signature == HotkeyManager.signature && hotKeyID.id == 1 {
            HotkeyManager.shared.actionHandler?()
        }
        return noErr
    }

    public init() {}

    /// Registers a global hotkey with specified virtual key code and modifier flags.
    public func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping @Sendable () -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.actionHandler = handler

            // Unregister prior registration
            if let existing = self.hotKeyRef {
                UnregisterEventHotKey(existing)
                self.hotKeyRef = nil
            }

            // Install Carbon event handler once
            if self.eventHandlerRef == nil {
                var ref: EventHandlerRef?
                let installStatus = InstallEventHandler(
                    GetApplicationEventTarget(),
                    Self.eventHandlerCallback,
                    1,
                    [Self.eventSpec],
                    nil,
                    &ref
                )
                if installStatus == noErr {
                    self.eventHandlerRef = ref
                } else {
                    self.logger.error("Failed to install Carbon event handler: \(installStatus)")
                }
            }

            let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
            let registerStatus = RegisterEventHotKey(
                keyCode,
                modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &self.hotKeyRef
            )

            if registerStatus == noErr {
                self.logger.info("Registered global hotkey (code: \(keyCode), mods: \(modifiers))")
            } else {
                self.logger.error("Failed to register global hotkey: \(registerStatus)")
            }
        }
    }

    /// Unregisters the active hotkey.
    public func unregister() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let ref = self.hotKeyRef {
                UnregisterEventHotKey(ref)
                self.hotKeyRef = nil
            }
        }
    }

    // MARK: - Display & Formatting Helpers

    public static func string(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> String {
        var str = ""
        if flags.contains(.control) { str += "⌃" }
        if flags.contains(.option) { str += "⌥" }
        if flags.contains(.shift) { str += "⇧" }
        if flags.contains(.command) { str += "⌘" }
        str += keyName(for: keyCode)
        return str
    }

    public static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        return mods
    }

    public static func nsFlags(fromCarbon mods: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if mods & UInt32(cmdKey) != 0 { flags.insert(.command) }
        if mods & UInt32(optionKey) != 0 { flags.insert(.option) }
        if mods & UInt32(controlKey) != 0 { flags.insert(.control) }
        if mods & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        return flags
    }

    public static func keyName(for keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "␣"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Escape: return "⎋"
        default: return "Key(\(keyCode))"
        }
    }
}
