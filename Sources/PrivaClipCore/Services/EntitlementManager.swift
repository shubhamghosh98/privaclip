import Foundation

public enum ProFeature: String, CaseIterable, Sendable {
    case smartCollections = "Smart Collections"
    case snippetVault = "Snippet Library"
    case advancedFilters = "Advanced Search & Filters"
    case exclusionRules = "Application Exclusion Rules"
    case encryptedBackup = "Encrypted Backup & Restore"
}

/// Gating controller managing Free vs Pro feature availability.
public enum EntitlementManager {
    /// Returns true if Pro features are active (via preference / license / dev entitlement).
    public static var isProActive: Bool {
        AppPreferences.shared.isProUnlocked
    }

    /// Checks if a specific feature is accessible.
    public static func isFeatureAvailable(_ feature: ProFeature) -> Bool {
        // Core functionality is always free; Pro unlocks differentiated productivity enhancements.
        return isProActive
    }
}
