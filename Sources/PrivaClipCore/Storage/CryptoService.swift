import Foundation
import CryptoKit
import CommonCrypto

public enum CryptoError: LocalizedError, Sendable {
    case encryptionFailed
    case decryptionFailed
    case invalidKeySize
    case corruptedData

    public var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "AES-GCM encryption failed."
        case .decryptionFailed:
            return "AES-GCM decryption failed or authentication tag mismatch."
        case .invalidKeySize:
            return "The cryptographic key has an invalid length."
        case .corruptedData:
            return "The data payload is corrupted or incomplete."
        }
    }
}

/// Provides authenticated AES-GCM encryption, decryption, and key derivation utilities.
public enum CryptoService {
    /// Encrypts plaintext data using AES-GCM with a random 12-byte nonce.
    public static func encrypt(data: Data, using key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                throw CryptoError.encryptionFailed
            }
            return combined
        } catch {
            throw CryptoError.encryptionFailed
        }
    }

    /// Decrypts ciphertext previously sealed using AES-GCM.
    public static func decrypt(combinedData: Data, using key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw CryptoError.decryptionFailed
        }
    }

    /// Computes the SHA-256 hexadecimal hash string for data deduplication.
    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Derives a 256-bit AES key from a user password and salt using PBKDF2-HMAC-SHA256.
    public static func deriveKey(from password: String, salt: Data, rounds: UInt32 = 100_000) -> SymmetricKey {
        var derivedKeyData = Data(count: 32)
        let passwordData = Data(password.utf8)

        _ = derivedKeyData.withUnsafeMutableBytes { derivedBytes in
            passwordData.withUnsafeBytes { passBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        rounds,
                        derivedBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }
        return SymmetricKey(data: derivedKeyData)
    }

    /// Generates cryptographically secure random bytes of the specified count.
    public static func randomBytes(count: Int) -> Data {
        var data = Data(count: count)
        _ = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!)
        }
        return data
    }
}
