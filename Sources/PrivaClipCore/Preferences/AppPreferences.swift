import Foundation
import ServiceManagement
import Carbon
import os

/// User configurable settings and persistence via UserDefaults.
public final class AppPreferences: @unchecked Sendable {
    public static let shared = AppPreferences()

    private let logger = Logger(subsystem: "com.privaclip.app", category: "preferences")
    private let defaults = UserDefaults.standard
    private let lock = NSLock()

    public static let historySizeChangedNotification = Notification.Name("com.privaclip.preferences.historySizeChanged")
    public static let proStatusChangedNotification = Notification.Name("com.privaclip.preferences.proStatusChanged")

    public struct HotkeyConfig: Equatable, Codable, Sendable {
        public var keyCode: UInt32
        public var modifiers: UInt32

        public init(keyCode: UInt32, modifiers: UInt32) {
            self.keyCode = keyCode
            self.modifiers = modifiers
        }
    }

    public static let defaultHotkey = HotkeyConfig(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(optionKey)
    )

    public static let historySizePresets = [50, 100, 250, 500, 1000, 2000]
    public static let defaultHistorySize = 100

    private enum Keys {
        static let hotkeyCode = "privaclip.hotkey.keyCode"
        static let hotkeyModifiers = "privaclip.hotkey.modifiers"
        static let historySize = "privaclip.historySize"
        static let launchAtLogin = "privaclip.launchAtLogin"
        static let autoPaste = "privaclip.autoPaste"
        static let excludedApps = "privaclip.excludedApps"
        static let proUnlocked = "privaclip.proUnlocked"
        static let soundEnabled = "privaclip.soundEnabled"
    }

    public init() {}

    public var hotkey: HotkeyConfig {
        get {
            lock.lock()
            defer { lock.unlock() }
            let k = (defaults.object(forKey: Keys.hotkeyCode) as? Int).map(UInt32.init) ?? Self.defaultHotkey.keyCode
            let m = (defaults.object(forKey: Keys.hotkeyModifiers) as? Int).map(UInt32.init) ?? Self.defaultHotkey.modifiers
            return HotkeyConfig(keyCode: k, modifiers: m)
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            defaults.set(Int(newValue.keyCode), forKey: Keys.hotkeyCode)
            defaults.set(Int(newValue.modifiers), forKey: Keys.hotkeyModifiers)
        }
    }

    public var historySize: Int {
        get {
            lock.lock()
            defer { lock.unlock() }
            let raw = defaults.object(forKey: Keys.historySize) as? Int ?? Self.defaultHistorySize
            return max(10, min(5000, raw))
        }
        set {
            lock.lock()
            let clamped = max(10, min(5000, newValue))
            defaults.set(clamped, forKey: Keys.historySize)
            lock.unlock()
            NotificationCenter.default.post(name: Self.historySizeChangedNotification, object: nil)
        }
    }

    public var launchAtLogin: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return defaults.bool(forKey: Keys.launchAtLogin)
        }
        set {
            lock.lock()
            defaults.set(newValue, forKey: Keys.launchAtLogin)
            lock.unlock()
            applyLaunchAtLogin(newValue)
        }
    }

    public var autoPaste: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            if defaults.object(forKey: Keys.autoPaste) == nil { return true }
            return defaults.bool(forKey: Keys.autoPaste)
        }
        set {
            lock.lock()
            defaults.set(newValue, forKey: Keys.autoPaste)
            lock.unlock()
        }
    }

    public var soundEnabled: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            if defaults.object(forKey: Keys.soundEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.soundEnabled)
        }
        set {
            lock.lock()
            defaults.set(newValue, forKey: Keys.soundEnabled)
            lock.unlock()
        }
    }

    public var excludedBundleIDs: Set<String> {
        get {
            lock.lock()
            defer { lock.unlock() }
            let list = defaults.stringArray(forKey: Keys.excludedApps) ?? []
            return Set(list)
        }
        set {
            lock.lock()
            defaults.set(Array(newValue), forKey: Keys.excludedApps)
            lock.unlock()
        }
    }

    /// Local development & test entitlement toggle for Pro features.
    public var isProUnlocked: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            // Default to unlocked for local testing unless explicitly toggled off
            if defaults.object(forKey: Keys.proUnlocked) == nil { return true }
            return defaults.bool(forKey: Keys.proUnlocked)
        }
        set {
            lock.lock()
            defaults.set(newValue, forKey: Keys.proUnlocked)
            lock.unlock()
            NotificationCenter.default.post(name: Self.proStatusChangedNotification, object: nil)
        }
    }

    public func syncLaunchAtLoginOnStartup() {
        if defaults.object(forKey: Keys.launchAtLogin) != nil {
            applyLaunchAtLogin(launchAtLogin)
        }
    }

    private func applyLaunchAtLogin(_ enable: Bool) {
        guard #available(macOS 13.0, *) else { return }
        let currentStatus = SMAppService.mainApp.status
        let isEnabled = (currentStatus == .enabled)
        guard isEnabled != enable else { return }
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Launch-at-login toggle failed: \(error.localizedDescription, privacy: .private)")
        }
    }
}
