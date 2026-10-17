import Foundation
import AppKit
import ApplicationServices
import Carbon
import os

public enum PasteResult: Sendable {
    case pastedSuccessfully
    case clipboardOnlyAccessibilityDenied
    case clipboardOnlyNoTargetApp
    case targetAppDidNotActivate
}

/// Dispatches clipboard items and synthesizes ⌘V keystrokes into previous target applications.
public final class AutoPaster: @unchecked Sendable {
    public static let shared = AutoPaster()

    private static let logger = Logger(subsystem: "com.privaclip.app", category: "autopaste")
    private static var didPromptAccessibility = false

    public init() {}

    /// Writes plain text to pasteboard and performs auto-paste.
    public static func paste(plainText: String, completion: (@Sendable (PasteResult) -> Void)? = nil) {
        copyToPasteboard(plain: plainText, representations: nil)
        deliverPaste(completion: completion)
    }

    /// Writes plain and rich-text representations to pasteboard and performs auto-paste.
    public static func paste(item: ClipItem, completion: (@Sendable (PasteResult) -> Void)? = nil) {
        if item.isImage, let fileName = item.imageFileName {
            DispatchQueue.global(qos: .userInitiated).async {
                if let png = ImageVault.shared.loadPNG(fileName: fileName) {
                    DispatchQueue.main.async {
                        copyToPasteboard(imageData: png)
                        deliverPaste(completion: completion)
                    }
                } else {
                    completion?(.clipboardOnlyNoTargetApp)
                }
            }
        } else {
            copyToPasteboard(plain: item.text, representations: item.richRepresentations)
            deliverPaste(completion: completion)
        }
    }

    /// Writes only to pasteboard without auto-paste injection.
    public static func copyOnly(item: ClipItem) {
        if item.isImage, let fileName = item.imageFileName {
            DispatchQueue.global(qos: .userInitiated).async {
                if let png = ImageVault.shared.loadPNG(fileName: fileName) {
                    DispatchQueue.main.async {
                        copyToPasteboard(imageData: png)
                    }
                }
            }
        } else {
            copyToPasteboard(plain: item.text, representations: item.richRepresentations)
        }
    }

    // MARK: - Pasteboard Writing

    public static func copyToPasteboard(plain: String, representations: [String: Data]?) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(plain, forType: .string)

        if let representations {
            for (rawType, data) in representations where rawType != NSPasteboard.PasteboardType.string.rawValue {
                pb.setData(data, forType: NSPasteboard.PasteboardType(rawType))
            }
        }
        ClipboardWatcher.shared.suppressNextChange()
    }

    public static func copyToPasteboard(imageData png: Data) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(png, forType: .png)
        ClipboardWatcher.shared.suppressNextChange()
    }

    // MARK: - Keystroke Injection & App Activation

    public static func deliverPaste(completion: (@Sendable (PasteResult) -> Void)? = nil) {
        guard AppPreferences.shared.autoPaste else {
            completion?(.pastedSuccessfully)
            return
        }

        guard let targetApp = ApplicationTracker.shared.lastActiveApp else {
            logger.info("No prior target application captured; content copied to clipboard only.")
            completion?(.clipboardOnlyNoTargetApp)
            return
        }

        guard checkAccessibilityTrust() else {
            logger.notice("Accessibility trust not granted; content copied to clipboard only.")
            completion?(.clipboardOnlyAccessibilityDenied)
            return
        }

        // macOS 14+ requires yielding activation before foreign app can take frontmost focus
        if #available(macOS 14.0, *) {
            NSApp.yieldActivation(to: targetApp)
        }
        targetApp.activate()

        let deadline = Date().addingTimeInterval(0.6)
        pollUntilFrontmost(app: targetApp, deadline: deadline, completion: completion)
    }

    private static func pollUntilFrontmost(
        app: NSRunningApplication,
        deadline: Date,
        completion: (@Sendable (PasteResult) -> Void)?
    ) {
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier {
            sendCmdV()
            completion?(.pastedSuccessfully)
            return
        }

        if Date() >= deadline {
            logger.error("Target application failed to become frontmost within deadline.")
            completion?(.targetAppDidNotActivate)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            pollUntilFrontmost(app: app, deadline: deadline, completion: completion)
        }
    }

    /// Verifies Accessibility permission and triggers the macOS dialog once if missing.
    public static func checkAccessibilityTrust() -> Bool {
        if AXIsProcessTrusted() { return true }
        if !didPromptAccessibility {
            didPromptAccessibility = true
            let options: NSDictionary = ["AXTrustedCheckOptionPrompt": true]
            _ = AXIsProcessTrustedWithOptions(options)
        }
        return false
    }

    private static func sendCmdV() {
        let keyCode = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        logger.info("Synthesized ⌘V posted via .cghidEventTap")
    }
}
