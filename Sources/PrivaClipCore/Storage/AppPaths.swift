import Foundation
import os

/// Manages filesystem directories and paths with restrictive POSIX permissions (0700/0600).
public enum AppPaths {
    private static let logger = Logger(subsystem: "com.privaclip.app", category: "paths")

    /// Testing hook: allows tests to isolate data in a temporary directory.
    public static var customBaseDirectory: URL? = nil

    /// Root storage directory: `~/Library/Application Support/PrivaClip/` (0700).
    public static var base: URL {
        if let custom = customBaseDirectory {
            ensureDirectory(custom)
            return custom
        }
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let folder = appSupport.appendingPathComponent("PrivaClip", isDirectory: true)
        ensureDirectory(folder)
        return folder
    }

    /// Subdirectory for encrypted image files: `.../PrivaClip/images/` (0700).
    public static var imagesFolder: URL {
        let folder = base.appendingPathComponent("images", isDirectory: true)
        ensureDirectory(folder)
        return folder
    }

    /// Subdirectory for encrypted export archives: `.../PrivaClip/backups/` (0700).
    public static var backupsFolder: URL {
        let folder = base.appendingPathComponent("backups", isDirectory: true)
        ensureDirectory(folder)
        return folder
    }

    /// Encrypted history store file URL.
    public static var historyFile: URL {
        base.appendingPathComponent("history.json.enc")
    }

    /// Encrypted snippets store file URL.
    public static var snippetsFile: URL {
        base.appendingPathComponent("snippets.json.enc")
    }

    /// Ensures the directory exists and has 0700 permissions.
    public static func ensureDirectory(_ url: URL) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            do {
                try fm.createDirectory(
                    at: url,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700]
                )
            } catch {
                logger.error("Failed to create directory \(url.path, privacy: .private): \(error.localizedDescription, privacy: .private)")
            }
        }
    }
}
