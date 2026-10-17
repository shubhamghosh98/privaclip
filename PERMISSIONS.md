# PrivaClip: macOS Permissions & System Integration

This document outlines the macOS system permissions utilized by **PrivaClip**, the technical rationale behind each requirement, and the fallback behaviors when permissions are withheld.

---

## Permission Summary

| macOS Permission | Required For | Required? | Fallback Mode Available? |
|---|---|---|---|
| **Accessibility** (`AXIsProcessTrusted`) | Direct Auto-Paste into target application | **Optional** (Recommended) | **Yes** (Copies to clipboard; user presses `⌘V` manually) |
| **Input Monitoring** | Global Keyboard Shortcut (`⌥V`) | **No** | N/A (Carbon HotKey API does not require permission) |
| **Screen Recording** | Visual previewing | **No** | N/A (Clipboard image data accessed directly via NSPasteboard) |
| **Network Access** | Telemetry or Cloud Sync | **No (Prohibited)** | Zero network calls |

---

## 1. Accessibility Permission (`AXIsProcessTrusted`)

### Why It Is Used
When you select an item from PrivaClip's history or snippet picker, the expected workflow is:
1. Dismiss the PrivaClip panel.
2. Reactivate the application you were working in (e.g. Safari, Xcode, Slack, VS Code).
3. Automatically paste the selected text or image into the active text field.

On macOS, simulating keyboard events into another application requires synthesizing a `CGEvent` with the `Command` modifier:
```swift
let source = CGEventSource(stateID: .combinedSessionState)
let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 0x09 = 'V'
keyDown?.flags = .maskCommand
keyDown?.post(tap: .cghidEventTap)

let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
keyUp?.flags = .maskCommand
keyUp?.post(tap: .cghidEventTap)
```

macOS security policy strictly restricts the synthesis of synthetic input events (`cghidEventTap` / `kCGAnnotatedSessionEventTap`) across process boundaries to applications that have been explicitly granted **Accessibility** access in System Settings.

### How PrivaClip Behaves If Accessibility Is Denied
PrivaClip treats Accessibility as an enhancement, not a mandatory prerequisite:
1. **No Crashes or Blocking Prompts**: PrivaClip verifies `AXIsProcessTrusted()` before attempting any event posting.
2. **Graceful Copy Fallback**: If Accessibility is not granted, PrivaClip:
   - Sets the selected content onto `NSPasteboard.general`.
   - Reactivates the previous application.
   - Shows a lightweight notification: *"Copied to clipboard. Press ⌘V to paste (Accessibility permission needed for auto-paste)."*
3. **One-Click Authorization**: The PrivaClip Preferences panel includes a dedicated Privacy tab showing the real-time status of the Accessibility permission, with a direct button to open macOS System Settings.

### How to Grant Accessibility Permission Manually
1. Open **System Settings** on your Mac.
2. Navigate to **Privacy & Security** → **Accessibility**.
3. Toggle the switch next to **PrivaClip** to **ON**. (If prompted, enter your Mac administrator password or use Touch ID).

---

## 2. Global Hotkey (`⌥V`): No Input Monitoring Needed

Many clipboard managers use low-level event taps (`CGEventTapCreate`) to listen to all user keystrokes, which requires the invasive **Input Monitoring** permission.

**PrivaClip avoids this entirely.** Instead, it uses Apple's native **Carbon Event HotKey API**:
```swift
RegisterEventHotKey(
    keyCode,
    modifiers,
    hotKeyID,
    GetApplicationEventTarget(),
    0,
    &hotKeyRef
)
```

### Why This Is Superior for Privacy:
- Carbon Hotkeys register *only* the specific key combination requested (by default, `⌥V`).
- The operating system notifies PrivaClip only when that specific shortcut is pressed.
- PrivaClip **never** receives or inspects your normal keystrokes.
- No "Input Monitoring" system permission dialog is ever displayed.

---

## 3. Application Sandbox Architectural Trade-Off

In the macOS security architecture:
- **Sandboxed Applications**: Confined to an isolated container. They cannot synthesize keyboard events into other applications, meaning true auto-paste is technically impossible within standard App Sandbox constraints.
- **Unsandboxed Applications with Hardened Runtime**: Like Raycast, Alfred, 1Password, and Maccy, PrivaClip is distributed unsandboxed with **Hardened Runtime** enabled (`com.apple.security.app-sandbox = false`).

To ensure total user safety in this architecture, PrivaClip enforces:
- **Code Signing with Runtime Hardening**: Prevents dylib injection and debugging by unauthorized processes.
- **Disabled Network Entitlements**: Disables network client and server sockets.
- **POSIX 0700 Storage**: Isolates all saved files to the user's private application support folder.
