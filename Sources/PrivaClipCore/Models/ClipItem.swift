import Foundation

/// Represents a single stored clipboard history entry.
public struct ClipItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var kind: ClipKind
    public var text: String
    public var date: Date
    public var pinned: Bool

    // Image metadata
    public var imageFileName: String?
    public var imageWidth: Int?
    public var imageHeight: Int?
    public var imageHash: String?

    // Origin application metadata
    public var sourceBundleID: String?
    public var sourceAppName: String?

    // Rich-text representations (RTF, HTML, RTFD, etc.)
    public var richRepresentations: [String: Data]?

    // Smart collection classification tags
    public var smartTags: Set<SmartCollectionTag>

    public init(
        id: UUID = UUID(),
        kind: ClipKind = .text,
        text: String,
        date: Date = Date(),
        pinned: Bool = false,
        imageFileName: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        imageHash: String? = nil,
        sourceBundleID: String? = nil,
        sourceAppName: String? = nil,
        richRepresentations: [String: Data]? = nil,
        smartTags: Set<SmartCollectionTag> = []
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.date = date
        self.pinned = pinned
        self.imageFileName = imageFileName
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.imageHash = imageHash
        self.sourceBundleID = sourceBundleID
        self.sourceAppName = sourceAppName
        self.richRepresentations = richRepresentations
        self.smartTags = smartTags
    }

    public var isImage: Bool {
        kind == .image
    }

    public var characterCount: Int {
        text.count
    }

    public var displayTitle: String {
        if isImage {
            if let w = imageWidth, let h = imageHeight {
                return "Image (\(w) × \(h))"
            }
            return "Image"
        }
        let firstLine = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? text
        return String(firstLine.prefix(80))
    }
}

/// Capture representation emitted by ClipboardWatcher
public enum CapturedContent: Sendable {
    case text(
        plain: String,
        richReps: [String: Data]?,
        bundleID: String?,
        appName: String?
    )
    case image(
        pngData: Data,
        width: Int,
        height: Int,
        bundleID: String?,
        appName: String?
    )
}
