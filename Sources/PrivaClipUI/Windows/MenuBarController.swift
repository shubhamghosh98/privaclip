import Foundation
import AppKit
import PrivaClipCore

/// Controls the system status item in the macOS menu bar and its context menu.
public final class MenuBarController: NSObject, @unchecked Sendable {
    private let statusItem: NSStatusItem
    private let historyVM: HistoryViewModel
    private let snippetsVM: SnippetsViewModel
    private let onOpenPreferences: () -> Void

    public init(
        historyVM: HistoryViewModel,
        snippetsVM: SnippetsViewModel,
        onOpenPreferences: @escaping () -> Void
    ) {
        self.historyVM = historyVM
        self.snippetsVM = snippetsVM
        self.onOpenPreferences = onOpenPreferences
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "PrivaClip")
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let type = event?.type
        let isCtrl = event?.modifierFlags.contains(.control) ?? false

        if type == .rightMouseUp || (type == .leftMouseUp && isCtrl) {
            showContextMenu()
        } else {
            ApplicationTracker.shared.captureFrontmost()
            FloatingPanelController.shared.toggle(
                at: NSEvent.mouseLocation,
                historyVM: historyVM,
                snippetsVM: snippetsVM
            )
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open PrivaClip", action: #selector(menuTogglePanel), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        if !AutoPaster.checkAccessibilityTrust() {
            let axItem = NSMenuItem(
                title: "Enable Auto-Paste (Accessibility)…",
                action: #selector(menuOpenAccessibility),
                keyEquivalent: ""
            )
            axItem.target = self
            menu.addItem(axItem)
        }

        menu.addItem(.separator())

        // History size submenu
        let currentSize = AppPreferences.shared.historySize
        let historyMenuItem = NSMenuItem(title: "History Size: \(currentSize)", action: nil, keyEquivalent: "")
        let subMenu = NSMenu()
        for size in AppPreferences.historySizePresets {
            let item = NSMenuItem(
                title: "\(size) items",
                action: #selector(menuSetHistorySize(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = size
            item.state = (size == currentSize) ? .on : .off
            subMenu.addItem(item)
        }
        historyMenuItem.submenu = subMenu
        menu.addItem(historyMenuItem)

        // Launch at login toggle
        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(menuToggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = AppPreferences.shared.launchAtLogin ? .on : .off
        menu.addItem(launchItem)

        // Preferences item
        let prefItem = NSMenuItem(
            title: "Preferences…",
            action: #selector(menuOpenPreferences),
            keyEquivalent: ","
        )
        prefItem.target = self
        menu.addItem(prefItem)

        menu.addItem(.separator())

        // Quit item
        let quitItem = NSMenuItem(
            title: "Quit PrivaClip",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        menu.addItem(quitItem)

        if let button = statusItem.button {
            let point = NSPoint(x: 0, y: button.bounds.height + 4)
            menu.popUp(positioning: nil, at: point, in: button)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func menuTogglePanel() {
        ApplicationTracker.shared.captureFrontmost()
        FloatingPanelController.shared.toggle(
            at: NSEvent.mouseLocation,
            historyVM: historyVM,
            snippetsVM: snippetsVM
        )
    }

    @objc private func menuOpenAccessibility() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func menuSetHistorySize(_ sender: NSMenuItem) {
        let size = sender.tag
        if size > 0 {
            AppPreferences.shared.historySize = size
        }
    }

    @objc private func menuToggleLaunchAtLogin() {
        AppPreferences.shared.launchAtLogin.toggle()
    }

    @objc private func menuOpenPreferences() {
        onOpenPreferences()
    }
}
