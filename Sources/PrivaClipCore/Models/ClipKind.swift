import Foundation

/// Describes the primary format of a stored clipboard item.
public enum ClipKind: String, Codable, Sendable, CaseIterable {
    case text
    case image
    case richText
}
