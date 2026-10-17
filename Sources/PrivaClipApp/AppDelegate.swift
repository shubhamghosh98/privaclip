import SwiftUI
import AppKit
import PrivaClipCore
import PrivaClipUI
import os

/// Application lifecycle coordinator and service bootstrapper.
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.privaclip.app", category: "lifecycle")

    public private(set) var historyVM: HistoryViewModel!
    public private(set) var snippetsVM: SnippetsViewModel!
    private var menuBarController: MenuBarController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        logger.notice("PrivaClip launching on macOS (Apple Silicon native)...")

        // 1. Ensure master AES-256 encryption key exists in Keychain
        do {
            try KeyManager.shared.ensureKeyExists()
            logger.notice("Encryption key ready in Keychain.")
        } catch {
            logger.error("KeyManager initialization failed: \(error.localizedDescription, privacy: .private)")
        }

        // 2. Initialize ViewModels on MainActor
        historyVM = HistoryViewModel()
        snippetsVM = SnippetsViewModel()

        // 3. Sync launch-at-login preference
        AppPreferences.shared.syncLaunchAtLoginOnStartup()

        // 4. Start foreground application tracking
        ApplicationTracker.shared.startTracking()

        // 5. Start clipboard monitoring
        ClipboardWatcher.shared.start { [weak self] content in
            DispatchQueue.main.async {
                self?.historyVM.addCapturedContent(content)
            }
        }

        // 6. Register global hotkey (default ⌥V)
        registerHotkey()

        // 7. Install Menu Bar status item
        menuBarController = MenuBarController(
            historyVM: historyVM,
            snippetsVM: snippetsVM,
            onOpenPreferences: { [weak self] in
                guard let self else { return }
                FloatingPanelController.shared.openPreferences(
                    historyVM: self.historyVM,
                    snippetsVM: self.snippetsVM
                )
            }
        )

        // 8. Pre-warm floating panel off-screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            FloatingPanelController.shared.prewarm(
                historyVM: self.historyVM,
                snippetsVM: self.snippetsVM
            )
        }

        logger.notice("PrivaClip initialized successfully. Zero network, at-rest encrypted.")
    }

    public func registerHotkey() {
        let config = AppPreferences.shared.hotkey
        HotkeyManager.shared.register(keyCode: config.keyCode, modifiers: config.modifiers) { [weak self] in
            guard let self else { return }
            ApplicationTracker.shared.captureFrontmost()
            FloatingPanelController.shared.toggle(
                at: NSEvent.mouseLocation,
                historyVM: self.historyVM,
                snippetsVM: self.snippetsVM
            )
        }
    }
}
