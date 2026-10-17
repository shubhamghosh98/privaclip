import Foundation
import CryptoKit
import os

public enum BackupError: LocalizedError, Sendable {
    case invalidFileHeader
    case invalidPasswordOrCorruptData
    case encodingFailed
    case decodingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidFileHeader:
            return "The archive does not appear to be a valid PrivaClip backup."
        case .invalidPasswordOrCorruptData:
            return "Incorrect password or corrupted backup archive."
        case .encodingFailed:
            return "Failed to serialize the backup archive."
        case .decodingFailed:
            return "Failed to parse decrypted backup data."
        }
    }
}

private struct BackupArchive: Codable {
    let version: Int
    let exportDate: Date
    let items: [ClipItem]
    let snippets: [Snippet]
    let images: [String: Data] // fileName -> raw PNG bytes
}

/// Creates and restores encrypted, password-protected archive files (.privaclip).
public enum BackupService {
    private static let logger = Logger(subsystem: "com.privaclip.app", category: "backup")
    private static let magicHeader = "PRVACLP1".data(using: .utf8)!
    private static let saltLength = 16

    /// Exports all items, snippets, and images into an AES-GCM encrypted archive protected by a user passphrase.
    public static func exportArchive(
        items: [ClipItem],
        snippets: [Snippet],
        password: String,
        destinationURL: URL
    ) throws {
        // Collect referenced images
        var imagesMap: [String: Data] = [:]
        for item in items where item.isImage {
            if let fn = item.imageFileName, let png = ImageVault.shared.loadPNG(fileName: fn) {
                imagesMap[fn] = png
            }
        }

        let archive = BackupArchive(
            version: 1,
            exportDate: Date(),
            items: items,
            snippets: snippets,
            images: imagesMap
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let jsonData = try? encoder.encode(archive) else {
            throw BackupError.encodingFailed
        }

        let salt = CryptoService.randomBytes(count: saltLength)
        let derivedKey = CryptoService.deriveKey(from: password, salt: salt)

        let encryptedPayload: Data
        do {
            encryptedPayload = try CryptoService.encrypt(data: jsonData, using: derivedKey)
        } catch {
            throw BackupError.encodingFailed
        }

        var fullData = Data()
        fullData.append(magicHeader)
        fullData.append(salt)
        fullData.append(encryptedPayload)

        try fullData.write(to: destinationURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destinationURL.path)
        logger.notice("Successfully exported encrypted archive to \(destinationURL.lastPathComponent, privacy: .public)")
    }

    /// Decrypts and imports items and snippets from a .privaclip archive.
    public static func importArchive(
        sourceURL: URL,
        password: String
    ) throws -> (items: [ClipItem], snippets: [Snippet]) {
        let fullData = try Data(contentsOf: sourceURL)
        let headerLen = magicHeader.count
        guard fullData.count > headerLen + saltLength else {
            throw BackupError.invalidFileHeader
        }

        let fileHeader = fullData.prefix(headerLen)
        guard fileHeader == magicHeader else {
            throw BackupError.invalidFileHeader
        }

        let salt = fullData.subdata(in: headerLen ..< (headerLen + saltLength))
        let encryptedPayload = fullData.subdata(in: (headerLen + saltLength) ..< fullData.count)

        let derivedKey = CryptoService.deriveKey(from: password, salt: salt)

        let decryptedData: Data
        do {
            decryptedData = try CryptoService.decrypt(combinedData: encryptedPayload, using: derivedKey)
        } catch {
            throw BackupError.invalidPasswordOrCorruptData
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let archive = try? decoder.decode(BackupArchive.self, from: decryptedData) else {
            throw BackupError.decodingFailed
        }

        // Restore image files to ImageVault
        for (fn, png) in archive.images {
            ImageVault.shared.save(pngData: png, fileName: fn)
        }

        logger.notice("Successfully imported \(archive.items.count) items and \(archive.snippets.count) snippets from archive.")
        return (archive.items, archive.snippets)
    }
}
