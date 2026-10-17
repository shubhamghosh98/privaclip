import Foundation
import os

private struct EncryptedHistoryPayload: Codable {
    let version: Int
    let items: [ClipItem]
}

private struct EncryptedSnippetPayload: Codable {
    let version: Int
    let snippets: [Snippet]
}

/// Handles authenticated encrypted persistence for clipboard history and snippet collections.
public final class PersistenceManager: @unchecked Sendable {
    public static let shared = PersistenceManager()

    private let logger = Logger(subsystem: "com.privaclip.app", category: "persistence")
    private let ioQueue = DispatchQueue(label: "com.privaclip.persistence.io", qos: .utility)
    private let schemaVersion = 1

    private static let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }()

    private static let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()

    public init() {}

    // MARK: - History Persistence

    /// Saves history items asynchronously with AES-GCM encryption and atomic write.
    public func saveHistory(items: [ClipItem], completion: (@Sendable () -> Void)? = nil) {
        let snapshot = items
        let version = schemaVersion
        let destination = AppPaths.historyFile

        ioQueue.async { [weak self] in
            guard let self else { return }
            do {
                let payload = EncryptedHistoryPayload(version: version, items: snapshot)
                let rawJSON = try Self.encoder.encode(payload)
                let key = try KeyManager.shared.getKey()
                let encrypted = try CryptoService.encrypt(data: rawJSON, using: key)
                try encrypted.write(to: destination, options: .atomic)
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
            } catch {
                self.logger.error("Failed to save encrypted history: \(error.localizedDescription, privacy: .private)")
            }
            completion?()
        }
    }

    /// Loads and decrypts history items synchronously on startup.
    public func loadHistory() -> [ClipItem] {
        let file = AppPaths.historyFile
        guard FileManager.default.fileExists(atPath: file.path) else {
            return []
        }

        do {
            let encryptedData = try Data(contentsOf: file)
            let key = try KeyManager.shared.getKey()
            let decryptedData = try CryptoService.decrypt(combinedData: encryptedData, using: key)

            if let payload = try? Self.decoder.decode(EncryptedHistoryPayload.self, from: decryptedData) {
                return payload.items
            }

            // Fallback for legacy arrays
            if let legacyItems = try? Self.decoder.decode([ClipItem].self, from: decryptedData) {
                logger.info("Migrated unversioned legacy history items.")
                return legacyItems
            }

            logger.error("History payload unparseable; quarantining corrupted file.")
            quarantine(url: file, prefix: "history.corrupted")
            return []
        } catch {
            logger.error("Decryption failed for history; quarantining corrupted file: \(error.localizedDescription, privacy: .private)")
            quarantine(url: file, prefix: "history.corrupted")
            return []
        }
    }

    // MARK: - Snippets Persistence

    /// Saves snippet library entries.
    public func saveSnippets(snippets: [Snippet], completion: (@Sendable () -> Void)? = nil) {
        let snapshot = snippets
        let version = schemaVersion
        let destination = AppPaths.snippetsFile

        ioQueue.async { [weak self] in
            guard let self else { return }
            do {
                let payload = EncryptedSnippetPayload(version: version, snippets: snapshot)
                let rawJSON = try Self.encoder.encode(payload)
                let key = try KeyManager.shared.getKey()
                let encrypted = try CryptoService.encrypt(data: rawJSON, using: key)
                try encrypted.write(to: destination, options: .atomic)
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
            } catch {
                self.logger.error("Failed to save encrypted snippets: \(error.localizedDescription, privacy: .private)")
            }
            completion?()
        }
    }

    /// Loads and decrypts snippet library entries.
    public func loadSnippets() -> [Snippet] {
        let file = AppPaths.snippetsFile
        guard FileManager.default.fileExists(atPath: file.path) else {
            return defaultSnippets()
        }

        do {
            let encryptedData = try Data(contentsOf: file)
            let key = try KeyManager.shared.getKey()
            let decryptedData = try CryptoService.decrypt(combinedData: encryptedData, using: key)

            if let payload = try? Self.decoder.decode(EncryptedSnippetPayload.self, from: decryptedData) {
                return payload.snippets
            }

            quarantine(url: file, prefix: "snippets.corrupted")
            return defaultSnippets()
        } catch {
            logger.error("Decryption failed for snippets; quarantining file: \(error.localizedDescription, privacy: .private)")
            quarantine(url: file, prefix: "snippets.corrupted")
            return defaultSnippets()
        }
    }

    // MARK: - Quarantine

    private func quarantine(url: URL, prefix: String) {
        let timestamp = Int(Date().timeIntervalSince1970)
        let quarantinedURL = url.deletingLastPathComponent().appendingPathComponent("\(prefix)-\(timestamp)")
        do {
            try FileManager.default.moveItem(at: url, to: quarantinedURL)
            logger.notice("Quarantined corrupt file to \(quarantinedURL.lastPathComponent, privacy: .public)")
        } catch {
            logger.error("Failed to quarantine \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .private)")
        }
    }

    private func defaultSnippets() -> [Snippet] {
        [
            Snippet(
                title: "Email Greeting",
                content: "Hi {name},\n\nThank you for reaching out! I would be glad to help.\n\nBest regards,\n{sender}",
                category: "Communication",
                tags: ["email", "greeting"]
            ),
            Snippet(
                title: "Meeting Notes Template",
                content: "# Meeting: {topic}\nDate: {date}\nAttendees: {attendees}\n\n## Discussion\n- \n\n## Action Items\n- [ ] ",
                category: "Work",
                tags: ["template", "notes"]
            ),
            Snippet(
                title: "Bug Report Template",
                content: "### Steps to Reproduce\n1. {step1}\n2. {step2}\n\n### Expected Behavior\n{expected}\n\n### Actual Behavior\n{actual}",
                category: "Development",
                tags: ["code", "bug"]
            )
        ]
    }
}
