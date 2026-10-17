import SwiftUI
import PrivaClipCore

/// Main-actor view model managing settings, application exclusions, and archive backup operations.
@MainActor
public final class PreferencesViewModel: ObservableObject {
    @Published public var selectedTab: Int = 0
    @Published public var historySize: Int = AppPreferences.shared.historySize
    @Published public var launchAtLogin: Bool = AppPreferences.shared.launchAtLogin
    @Published public var autoPaste: Bool = AppPreferences.shared.autoPaste
    @Published public var isProUnlocked: Bool = AppPreferences.shared.isProUnlocked
    @Published public var excludedApps: [String] = Array(AppPreferences.shared.excludedBundleIDs).sorted()
    @Published public var newExcludedBundle: String = ""

    // Backup state
    @Published public var backupPassphrase: String = ""
    @Published public var backupStatusMessage: String?

    public init() {}

    public func updateHistorySize(_ size: Int) {
        historySize = size
        AppPreferences.shared.historySize = size
    }

    public func updateLaunchAtLogin(_ enable: Bool) {
        launchAtLogin = enable
        AppPreferences.shared.launchAtLogin = enable
    }

    public func updateAutoPaste(_ enable: Bool) {
        autoPaste = enable
        AppPreferences.shared.autoPaste = enable
    }

    public func updateProUnlocked(_ enable: Bool) {
        isProUnlocked = enable
        AppPreferences.shared.isProUnlocked = enable
    }

    public func addExcludedApp() {
        let trimmed = newExcludedBundle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var current = AppPreferences.shared.excludedBundleIDs
        current.insert(trimmed)
        AppPreferences.shared.excludedBundleIDs = current
        excludedApps = Array(current).sorted()
        newExcludedBundle = ""
    }

    public func removeExcludedApp(_ bundleID: String) {
        var current = AppPreferences.shared.excludedBundleIDs
        current.remove(bundleID)
        AppPreferences.shared.excludedBundleIDs = current
        excludedApps = Array(current).sorted()
    }
}
