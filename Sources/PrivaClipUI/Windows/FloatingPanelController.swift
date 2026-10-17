import SwiftUI
import AppKit
import PrivaClipCore

/// Custom NSPanel subclass that explicitly allows becoming key window so it can receive all keyboard events.
final class KeyFocusablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
public final class FloatingPanelController: NSObject, NSWindowDelegate {
    public static let shared = FloatingPanelController()

    private var panel: KeyFocusablePanel?
    private var outsideClickMonitor: Any?
    private var keyDownMonitor: Any?
    private var preferencesWindow: NSWindow?
    private weak var historyVM: HistoryViewModel?
    private weak var snippetsVM: SnippetsViewModel?

    public override init() {
        super.init()
    }

    /// Prewarms the panel off-screen so the first invocation has near-zero latency.
    public func prewarm(historyVM: HistoryViewModel, snippetsVM: SnippetsViewModel) {
        self.historyVM = historyVM
        self.snippetsVM = snippetsVM
        let p = ensurePanel(historyVM: historyVM, snippetsVM: snippetsVM)
        p.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        p.alphaValue = 0
        p.orderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            p.orderOut(nil)
            p.alphaValue = 1
        }
    }

    /// Toggles panel visibility at screenPoint.
    public func toggle(at screenPoint: NSPoint, historyVM: HistoryViewModel, snippetsVM: SnippetsViewModel) {
        if let p = panel, p.isVisible, p.alphaValue > 0 {
            close()
        } else {
            show(at: screenPoint, historyVM: historyVM, snippetsVM: snippetsVM)
        }
    }

    /// Presents the panel anchored near screenPoint.
    public func show(at screenPoint: NSPoint, historyVM: HistoryViewModel, snippetsVM: SnippetsViewModel) {
        self.historyVM = historyVM
        self.snippetsVM = snippetsVM

        // Auto-select first item if none is currently selected
        if historyVM.selectedID == nil {
            historyVM.selectedID = historyVM.filteredItems.first?.id
        }
        if snippetsVM.selectedSnippet == nil {
            snippetsVM.selectedSnippet = snippetsVM.filteredSnippets.first
        }

        let p = ensurePanel(historyVM: historyVM, snippetsVM: snippetsVM)
        positionPanel(p, near: screenPoint)
        p.alphaValue = 1

        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)

        installOutsideClickMonitor()
        installKeyDownMonitor()
    }

    public func close() {
        panel?.orderOut(nil)
        removeOutsideClickMonitor()
        removeKeyDownMonitor()
    }

    public func openPreferences(historyVM: HistoryViewModel, snippetsVM: SnippetsViewModel) {
        if let existing = preferencesWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let prefView = PreferencesView(historyVM: historyVM, snippetsVM: snippetsVM)
        let hosting = NSHostingView(rootView: prefView)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "PrivaClip Settings"
        win.contentView = hosting
        win.center()
        win.isReleasedWhenClosed = false
        self.preferencesWindow = win

        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    private func ensurePanel(historyVM: HistoryViewModel, snippetsVM: SnippetsViewModel) -> KeyFocusablePanel {
        if let existing = panel { return existing }

        let rootView = HistoryPanelView(
            historyVM: historyVM,
            snippetsVM: snippetsVM,
            onClose: { [weak self] in self?.close() },
            onOpenPreferences: { [weak self] in
                self?.openPreferences(historyVM: historyVM, snippetsVM: snippetsVM)
            }
        )
        let hosting = NSHostingView(rootView: rootView)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let p = KeyFocusablePanel(
            contentRect: NSRect(x: 0, y: 0, width: PrivaClipTheme.panelWidth, height: PrivaClipTheme.panelHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .titled],
            backing: .buffered,
            defer: false
        )
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.standardWindowButton(.closeButton)?.isHidden = true
        p.standardWindowButton(.miniaturizeButton)?.isHidden = true
        p.standardWindowButton(.zoomButton)?.isHidden = true
        p.isMovableByWindowBackground = true
        p.isFloatingPanel = true
        p.level = .floating
        p.collectionBehavior = [.transient, .ignoresCycle]
        p.isOpaque = false
        p.hasShadow = false
        p.backgroundColor = .clear
        p.animationBehavior = .none
        p.becomesKeyOnlyIfNeeded = false
        p.delegate = self
        p.isReleasedWhenClosed = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        p.contentView = container

        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.widthAnchor.constraint(equalToConstant: PrivaClipTheme.panelWidth),
            container.heightAnchor.constraint(equalToConstant: PrivaClipTheme.panelHeight)
        ])

        self.panel = p
        return p
    }

    private func positionPanel(_ panel: NSPanel, near point: NSPoint) {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(point) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }

        let halfW = PrivaClipTheme.panelWidth / 2
        var origin = NSPoint(
            x: point.x - halfW,
            y: point.y - 20 - PrivaClipTheme.panelHeight
        )

        let visible = screen.visibleFrame
        origin.x = max(visible.minX + 10, min(origin.x, visible.maxX - PrivaClipTheme.panelWidth - 10))
        origin.y = max(visible.minY + 10, min(origin.y, visible.maxY - 10))
        panel.setFrameOrigin(origin)
    }

    // MARK: - Event Monitors

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.close()
        }
    }

    private func removeOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    private func installKeyDownMonitor() {
        removeKeyDownMonitor()
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let p = self.panel, p.isVisible else { return event }

            let keyCode = event.keyCode
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // 1. ESCAPE (keyCode 53)
            if keyCode == 53 {
                if let hvm = self.historyVM, hvm.selectedTab == .history, !hvm.searchText.isEmpty {
                    hvm.searchText = ""
                    return nil
                }
                if let svm = self.snippetsVM, let hvm = self.historyVM, hvm.selectedTab == .snippets, !svm.searchText.isEmpty {
                    svm.searchText = ""
                    return nil
                }
                self.close()
                return nil
            }

            // 2. UP ARROW (keyCode 126)
            if keyCode == 126 {
                if let hvm = self.historyVM, hvm.selectedTab == .history {
                    hvm.selectPrevious()
                    return nil
                } else if let svm = self.snippetsVM {
                    svm.selectPrevious()
                    return nil
                }
            }

            // 3. DOWN ARROW (keyCode 125)
            if keyCode == 125 {
                if let hvm = self.historyVM, hvm.selectedTab == .history {
                    hvm.selectNext()
                    return nil
                } else if let svm = self.snippetsVM {
                    svm.selectNext()
                    return nil
                }
            }

            // 4. RETURN / ENTER (keyCode 36)
            if keyCode == 36 && flags.isEmpty {
                if let hvm = self.historyVM, hvm.selectedTab == .history {
                    hvm.pasteSelectedItem(onClose: { [weak self] in self?.close() })
                    return nil
                } else if let svm = self.snippetsVM {
                    svm.triggerSelectedItem(onClose: { [weak self] in self?.close() })
                    return nil
                }
            }

            // 5. DELETE (51) / FORWARD DELETE (117)
            if keyCode == 51 || keyCode == 117 {
                let searchEmpty: Bool
                if let hvm = self.historyVM, hvm.selectedTab == .history {
                    searchEmpty = hvm.searchText.isEmpty
                } else if let svm = self.snippetsVM {
                    searchEmpty = svm.searchText.isEmpty
                } else {
                    searchEmpty = true
                }

                if flags.contains(.command) || searchEmpty {
                    if let hvm = self.historyVM, hvm.selectedTab == .history {
                        hvm.deleteSelectedItem()
                        return nil
                    } else if let svm = self.snippetsVM {
                        svm.deleteSelectedItem()
                        return nil
                    }
                }
            }

            // 6. ⌘C (keyCode 8) -> Copy selected item only
            if keyCode == 8 && flags.contains(.command) {
                if let hvm = self.historyVM, hvm.selectedTab == .history {
                    hvm.copySelectedItemOnly(onClose: { [weak self] in self?.close() })
                    return nil
                }
            }

            // 7. ⌘P (keyCode 35) -> Toggle pin on selected item
            if keyCode == 35 && flags.contains(.command) {
                if let hvm = self.historyVM, hvm.selectedTab == .history {
                    hvm.togglePinSelectedItem()
                    return nil
                }
            }

            // 8. ⌘, (keyCode 43) -> Open preferences
            if keyCode == 43 && flags.contains(.command) {
                if let hvm = self.historyVM, let svm = self.snippetsVM {
                    self.openPreferences(historyVM: hvm, snippetsVM: svm)
                    return nil
                }
            }

            // 9. Tab (keyCode 48) -> Switch between History and Snippets tabs
            if keyCode == 48 && flags.isEmpty {
                if let hvm = self.historyVM {
                    hvm.selectedTab = (hvm.selectedTab == .history ? .snippets : .history)
                    return nil
                }
            }

            return event
        }
    }

    private func removeKeyDownMonitor() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
    }
}
