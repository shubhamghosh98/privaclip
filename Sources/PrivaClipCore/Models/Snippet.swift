import Foundation

/// Represents a reusable text snippet with optional parameter placeholders.
public struct Snippet: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var content: String
    public var category: String
    public var tags: [String]
    public var isFavorite: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        content: String,
        category: String = "General",
        tags: [String] = [],
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.category = category
        self.tags = tags
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Extracts placeholders defined in `{placeholder_name}` format.
    public var placeholders: [String] {
        let pattern = #"\{([a-zA-Z0-9_-]+)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
        var found: [String] = []
        for match in matches {
            if match.numberOfRanges > 1 {
                let range = match.range(at: 1)
                let name = nsContent.substring(with: range)
                if !found.contains(name) {
                    found.append(name)
                }
            }
        }
        return found
    }

    /// Substitutes placeholder keys with user-supplied values.
    public func resolve(with values: [String: String]) -> String {
        var resolved = content
        for (key, val) in values {
            resolved = resolved.replacingOccurrences(of: "{\(key)}", with: val)
        }
        return resolved
    }
}
