import Foundation
import AppKit
import ImageIO
import os

/// Secure, isolated on-disk storage and memory cache for clipboard image entries.
public final class ImageVault: @unchecked Sendable {
    public static let shared = ImageVault()

    private let logger = Logger(subsystem: "com.privaclip.app", category: "imagevault")
    private let ioQueue = DispatchQueue(label: "com.privaclip.imagevault.io", qos: .utility)
    private let pendingLock = NSLock()
    private var pendingPNG: [String: Data] = [:]

    private let thumbnailCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 150
        return cache
    }()

    public init() {}

    private func fileURL(for fileName: String) -> URL {
        AppPaths.imagesFolder.appendingPathComponent(fileName)
    }

    /// Stores raw PNG bytes encrypted with AES-GCM under `~/Library/Application Support/PrivaClip/images/`.
    public func save(pngData: Data, fileName: String) {
        pendingLock.lock()
        pendingPNG[fileName] = pngData
        pendingLock.unlock()

        let url = fileURL(for: fileName)
        let thumbKey = "\(fileName)@800" as NSString

        ioQueue.async { [weak self] in
            guard let self else { return }

            // Pre-compute thumbnail for smooth scrolling
            if let thumb = Self.makeThumbnail(from: pngData, maxPixelSize: 800) {
                self.thumbnailCache.setObject(thumb, forKey: thumbKey)
            }

            do {
                let key = try KeyManager.shared.getKey()
                let encrypted = try CryptoService.encrypt(data: pngData, using: key)
                try encrypted.write(to: url, options: .atomic)
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            } catch {
                self.logger.error("Failed to encrypt and save image \(fileName, privacy: .private): \(error.localizedDescription, privacy: .private)")
            }

            self.pendingLock.lock()
            self.pendingPNG[fileName] = nil
            self.pendingLock.unlock()
        }
    }

    /// Loads decrypted PNG data for pasting or high-resolution display.
    public func loadPNG(fileName: String) -> Data? {
        pendingLock.lock()
        let pending = pendingPNG[fileName]
        pendingLock.unlock()
        if let pending { return pending }

        let url = fileURL(for: fileName)
        guard let encryptedData = try? Data(contentsOf: url) else { return nil }
        guard let key = try? KeyManager.shared.getKey() else { return nil }
        return try? CryptoService.decrypt(combinedData: encryptedData, using: key)
    }

    /// Loads a full-resolution NSImage.
    public func loadFullImage(fileName: String) -> NSImage? {
        guard let data = loadPNG(fileName: fileName) else { return nil }
        return NSImage(data: data)
    }

    /// Loads or computes a thumbnail scaled to `maxPixelSize`.
    public func loadThumbnail(fileName: String, maxPixelSize: Int = 800) -> NSImage? {
        let key = "\(fileName)@\(maxPixelSize)" as NSString
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }
        guard let data = loadPNG(fileName: fileName),
              let thumb = Self.makeThumbnail(from: data, maxPixelSize: maxPixelSize) else {
            return nil
        }
        thumbnailCache.setObject(thumb, forKey: key)
        return thumb
    }

    /// Deletes an image file and purges its thumbnail from cache.
    public func delete(fileName: String) {
        pendingLock.lock()
        pendingPNG[fileName] = nil
        pendingLock.unlock()

        thumbnailCache.removeObject(forKey: "\(fileName)@800" as NSString)
        let url = fileURL(for: fileName)
        ioQueue.async {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Removes unreferenced image files left behind after crashes or external deletions.
    public func pruneOrphans(referenced: Set<String>) {
        ioQueue.async {
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(atPath: AppPaths.imagesFolder.path) else { return }
            for file in files where !referenced.contains(file) {
                let url = AppPaths.imagesFolder.appendingPathComponent(file)
                try? fm.removeItem(at: url)
            }
        }
    }

    /// Efficiently generates downscaled thumbnails using ImageIO without full bitmap decoding.
    public static func makeThumbnail(from pngData: Data, maxPixelSize: Int) -> NSImage? {
        guard let src = CGImageSourceCreateWithData(pngData as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
