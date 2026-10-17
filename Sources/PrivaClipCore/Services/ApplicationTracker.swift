import Foundation
import AppKit
import os

/// Tracks user application focus changes to identify paste-back targets and copy source applications.
public final class ApplicationTracker: @unchecked Sendable {
    public static let shared = ApplicationTracker()

    private let logger = Logger(subsystem: "com.privaclip.app", category: "tracker")
    private let lock = NSLock()
    private var _lastActiveApp: NSRunningApplication?

    public init() {}

    public var lastActiveApp: NSRunningApplication? {
        lock.lock()
        defer { lock.unlock() }
        return _lastActiveApp
    }

    /// Initializes workspace activation observation.
    public func startTracking() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            if app.bundleIdentifier != Bundle.main.bundleIdentifier {
                self.lock.lock()
                self._lastActiveApp = app
                self.lock.unlock()
            }
        }

        // Seed with current frontmost app
        captureFrontmost()
    }

    /// Snapshots the foreground application immediately prior to PrivaClip gaining focus.
    public func captureFrontmost() {
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != Bundle.main.bundleIdentifier {
            lock.lock()
            _lastActiveApp = front
            lock.unlock()
            logger.info("Captured target app for paste: \(front.localizedName ?? "?", privacy: .public)")
        }
    }

    /// Returns the bundle identifier and localized name of the current frontmost application (excluding self).
    public static func currentSourceApp() -> (bundleID: String?, appName: String?) {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return (nil, nil)
        }
        return (app.bundleIdentifier, app.localizedName)
    }
}
