import SwiftUI
import AppKit
import PrivaClipCore

/// Controls the floating HUD panel window that appears near the mouse or status bar.
public final class FloatingPanelController: NSObject, NSWindowDelegate, @unchecked Sendable {
    public static let shared = FloatingPanelController()

    private var panel: NSPanel?
    private var outsideClickMonitor: Any?
    private var preferencesWindow: NSWindow?

    public override init() {
        super.init()
    }

    /// Prewarms the panel off-screen so the first invocation has near-zero latency.
    public func prewarm(historyVM: HistoryViewModel, snippetsVM: SnippetsViewModel) {
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
        let p = ensurePanel(historyVM: historyVM, snippetsVM: snippetsVM)
        positionPanel(p, near: screenPoint)
        p.alphaValue = 1

        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)

        installOutsideClickMonitor()
    }

    public func close() {
        panel?.orderOut(nil)
        removeOutsideClickMonitor()
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

    private func ensurePanel(historyVM: HistoryViewModel, snippetsVM: SnippetsViewModel) -> NSPanel {
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

        let p = NSPanel(
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
}
