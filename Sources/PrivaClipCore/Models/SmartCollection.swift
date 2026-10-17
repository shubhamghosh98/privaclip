import Foundation

/// Categorization tags for Smart Collections.
public enum SmartCollectionTag: String, Codable, Sendable, CaseIterable, Identifiable {
    case all = "All"
    case links = "Links"
    case code = "Code"
    case emails = "Emails"
    case phones = "Phones"
    case colors = "Colors"
    case images = "Images"
    case snippets = "Snippets"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .all: return "tray.full"
        case .links: return "link"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .emails: return "envelope"
        case .phones: return "phone"
        case .colors: return "paintpalette"
        case .images: return "photo"
        case .snippets: return "doc.text.badge.plus"
        }
    }
}
