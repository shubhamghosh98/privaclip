import Foundation

/// Fast local classifier for categorizing clipboard text into Smart Collections.
public enum SmartClassifier {
    private static let emailRegex = try? NSRegularExpression(
        pattern: #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$"#,
        options: []
    )

    private static let phoneRegex = try? NSRegularExpression(
        pattern: #"^(\+?\d{1,4}?[-.\s]?)?(\(?\d{2,4}\)?[-.\s]?)?\d{3,4}[-.\s]?\d{3,4}$"#,
        options: []
    )

    private static let hexColorRegex = try? NSRegularExpression(
        pattern: #"^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3}|[A-Fa-f0-9]{8})$"#,
        options: []
    )

    private static let codeKeywords: [String] = [
        "func ", "function ", "def ", "class ", "struct ", "enum ", "import ",
        "export ", "const ", "let ", "var ", "return ", "public ", "private ",
        "protected ", "interface ", "implements ", "extends ", "switch ", "case ",
        "try ", "catch ", "throw ", "async ", "await ", "SELECT ", "FROM ", "WHERE ",
        "require(", "console.log(", "print(", "fmt.Println(", "package ", "namespace "
    ]

    /// Analyzes string content and returns applicable smart tags.
    public static func classify(text: String) -> Set<SmartCollectionTag> {
        var tags: Set<SmartCollectionTag> = []
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return tags }

        // 1. Link / URL detection
        if isURL(trimmed) {
            tags.insert(.links)
        }

        // 2. Email detection
        if isEmail(trimmed) {
            tags.insert(.emails)
        }

        // 3. Phone number detection
        if isPhone(trimmed) {
            tags.insert(.phones)
        }

        // 4. Color detection
        if isColor(trimmed) {
            tags.insert(.colors)
        }

        // 5. Code detection
        if isCode(text: text) {
            tags.insert(.code)
        }

        return tags
    }

    private static func isURL(_ str: String) -> Bool {
        if str.hasPrefix("http://") || str.hasPrefix("https://") || str.hasPrefix("ftp://") {
            return URL(string: str) != nil
        }
        if str.hasPrefix("www.") && URL(string: "https://" + str) != nil {
            return true
        }
        return false
    }

    private static func isEmail(_ str: String) -> Bool {
        guard let regex = emailRegex else { return false }
        let range = NSRange(location: 0, length: str.utf16.count)
        return regex.firstMatch(in: str, options: [], range: range) != nil
    }

    private static func isPhone(_ str: String) -> Bool {
        guard str.count >= 7 && str.count <= 20 else { return false }
        guard let regex = phoneRegex else { return false }
        let range = NSRange(location: 0, length: str.utf16.count)
        return regex.firstMatch(in: str, options: [], range: range) != nil
    }

    private static func isColor(_ str: String) -> Bool {
        if let regex = hexColorRegex {
            let range = NSRange(location: 0, length: str.utf16.count)
            if regex.firstMatch(in: str, options: [], range: range) != nil {
                return true
            }
        }
        let lower = str.lowercased()
        if (lower.hasPrefix("rgb(") || lower.hasPrefix("rgba(") || lower.hasPrefix("hsl(") || lower.hasPrefix("hsla(")) && lower.hasSuffix(")") {
            return true
        }
        return false
    }

    private static func isCode(text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. JSON detection
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            if (try? JSONSerialization.jsonObject(with: Data(trimmed.utf8))) != nil {
                return true
            }
        }

        // 2. HTML/XML detection
        if trimmed.hasPrefix("<") && trimmed.hasSuffix(">") && trimmed.contains("</") {
            return true
        }

        // 3. Keyword presence
        var keywordHits = 0
        for kw in codeKeywords {
            if text.contains(kw) {
                keywordHits += 1
            }
        }

        let hasSemicolons = text.contains(";")
        let hasBraces = text.contains("{") && text.contains("}")
        let hasParentheses = text.contains("(") && text.contains(")")
        let hasArrows = text.contains("->") || text.contains("=>")
        let hasAssignment = text.contains(" = ") || text.contains(": ")

        if keywordHits >= 2 { return true }
        if keywordHits >= 1 && (hasSemicolons || hasBraces || hasArrows || hasAssignment) { return true }
        if (hasBraces && (hasSemicolons || hasArrows)) || (hasParentheses && hasSemicolons && hasAssignment) {
            return true
        }

        return false
    }
}
