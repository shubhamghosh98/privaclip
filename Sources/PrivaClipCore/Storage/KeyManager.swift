import Foundation
import Security
import CryptoKit
import os

public enum KeyManagerError: LocalizedError, Sendable {
    case keychainError(status: OSStatus)
    case keyNotFound
    case keyGenerationFailed
    case encodingError

    public var errorDescription: String? {
        switch self {
        case .keychainError(let status):
            return "Keychain operation failed with OSStatus \(status)."
        case .keyNotFound:
            return "Encryption key was not found in the Keychain."
        case .keyGenerationFailed:
            return "Failed to generate symmetric encryption key."
        case .encodingError:
            return "Failed to encode or decode encryption key data."
        }
    }
}

/// Thread-safe manager for generating and retrieving the master AES-256 encryption key from macOS Keychain.
public final class KeyManager: @unchecked Sendable {
    public static let shared = KeyManager()

    private let logger = Logger(subsystem: "com.privaclip.app", category: "crypto")
    private let service = "com.privaclip.manager"
    private let account = "com.privaclip.encryptionKey"
    private let lock = NSLock()
    private var cachedKey: SymmetricKey?

    /// Testing flag to bypass Keychain and test completely in-memory.
    public var useInMemoryKeyForTesting: Bool = false
    private var inMemoryTestKey: SymmetricKey?

    public init() {}

    /// Ensures a valid 256-bit symmetric key is stored in the Keychain.
    @discardableResult
    public func ensureKeyExists() throws -> SymmetricKey {
        lock.lock()
        defer { lock.unlock() }

        if useInMemoryKeyForTesting {
            if let key = inMemoryTestKey { return key }
            let key = SymmetricKey(size: .bits256)
            inMemoryTestKey = key
            return key
        }

        if let cached = cachedKey {
            return cached
        }

        if let key = try? loadKeyFromKeychain() {
            cachedKey = key
            return key
        }

        let newKey = SymmetricKey(size: .bits256)
        try storeKeyInKeychain(key: newKey)
        cachedKey = newKey
        logger.notice("New 256-bit AES master key generated and stored in Keychain.")
        return newKey
    }

    /// Retrieves the current symmetric key, loading from Keychain if needed.
    public func getKey() throws -> SymmetricKey {
        lock.lock()
        defer { lock.unlock() }

        if useInMemoryKeyForTesting {
            if let key = inMemoryTestKey { return key }
            let key = SymmetricKey(size: .bits256)
            inMemoryTestKey = key
            return key
        }

        if let cached = cachedKey { return cached }
        let key = try loadKeyFromKeychain()
        cachedKey = key
        return key
    }

    /// Deletes the master key from the Keychain. Existing encrypted data will become permanently unreadable.
    public func deleteKey() throws {
        lock.lock()
        defer { lock.unlock() }

        if useInMemoryKeyForTesting {
            inMemoryTestKey = nil
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeyManagerError.keychainError(status: status)
        }
        cachedKey = nil
        logger.notice("Master key deleted from Keychain.")
    }

    // MARK: - Private Keychain Helpers

    private func loadKeyFromKeychain() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeyManagerError.keyNotFound
        }
        return SymmetricKey(data: data)
    }

    private func storeKeyInKeychain(key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        // Delete any stale item first
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeyManagerError.keychainError(status: status)
        }
    }
}
