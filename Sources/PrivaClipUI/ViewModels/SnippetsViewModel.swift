import SwiftUI
import Combine
import PrivaClipCore

/// Main-actor view model managing reusable snippets and placeholder expansion.
@MainActor
public final class SnippetsViewModel: ObservableObject {
    @Published public private(set) var snippets: [Snippet] = []
    @Published public var searchText: String = ""
    @Published public var selectedCategory: String = "All"
    @Published public var selectedSnippet: Snippet?
    @Published public var activePlaceholderSnippet: Snippet?
    @Published public var placeholderValues: [String: String] = [:]
    @Published public var statusMessage: String?

    // Add snippet modal state
    @Published public var showingAddSheet: Bool = false
    @Published public var newTitle: String = ""
    @Published public var newContent: String = ""
    @Published public var newCategory: String = "General"

    private var cancellables = Set<AnyCancellable>()
    private let saveSubject = PassthroughSubject<Void, Never>()

    public init() {
        self.snippets = PersistenceManager.shared.loadSnippets()

        saveSubject
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                PersistenceManager.shared.saveSnippets(snippets: self.snippets)
            }
            .store(in: &cancellables)
    }

    public func scheduleSave() {
        saveSubject.send(())
    }

    public var categories: [String] {
        var set = Set(snippets.map { $0.category })
        set.insert("All")
        return Array(set).sorted()
    }

    public var filteredSnippets: [Snippet] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return snippets.filter { snippet in
            if selectedCategory != "All" && snippet.category != selectedCategory {
                return false
            }
            if !q.isEmpty {
                let matchTitle = snippet.title.localizedCaseInsensitiveContains(q)
                let matchContent = snippet.content.localizedCaseInsensitiveContains(q)
                let matchTags = snippet.tags.contains { $0.localizedCaseInsensitiveContains(q) }
                return matchTitle || matchContent || matchTags
            }
            return true
        }
    }

    public func addSnippet(title: String, content: String, category: String, tags: [String] = []) {
        let snippet = Snippet(
            title: title,
            content: content,
            category: category.isEmpty ? "General" : category,
            tags: tags
        )
        snippets.insert(snippet, at: 0)
        scheduleSave()
    }

    public func updateSnippet(_ snippet: Snippet) {
        if let idx = snippets.firstIndex(where: { $0.id == snippet.id }) {
            var updated = snippet
            updated.updatedAt = Date()
            snippets[idx] = updated
            scheduleSave()
        }
    }

    public func deleteSnippet(id: UUID) {
        snippets.removeAll(where: { $0.id == id })
        if selectedSnippet?.id == id {
            selectedSnippet = nil
        }
        scheduleSave()
    }

    public func toggleFavorite(id: UUID) {
        if let idx = snippets.firstIndex(where: { $0.id == id }) {
            snippets[idx].isFavorite.toggle()
            scheduleSave()
        }
    }

    public func triggerSnippet(_ snippet: Snippet, pasteDirectly: Bool = true) {
        let placeholders = snippet.placeholders
        if placeholders.isEmpty {
            executeInsert(content: snippet.content, pasteDirectly: pasteDirectly)
        } else {
            placeholderValues = [:]
            for ph in placeholders {
                placeholderValues[ph] = ""
            }
            activePlaceholderSnippet = snippet
        }
    }

    public func submitPlaceholderSnippet(pasteDirectly: Bool = true) {
        guard let snippet = activePlaceholderSnippet else { return }
        let resolved = snippet.resolve(with: placeholderValues)
        activePlaceholderSnippet = nil
        placeholderValues = [:]
        executeInsert(content: resolved, pasteDirectly: pasteDirectly)
    }

    public func cancelPlaceholderSnippet() {
        activePlaceholderSnippet = nil
        placeholderValues = [:]
    }

    private func executeInsert(content: String, pasteDirectly: Bool) {
        if pasteDirectly && AppPreferences.shared.autoPaste {
            AutoPaster.paste(plainText: content) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .pastedSuccessfully:
                        self?.statusMessage = "Snippet inserted"
                    default:
                        self?.statusMessage = "Snippet copied to clipboard"
                    }
                    self?.dismissStatus()
                }
            }
        } else {
            AutoPaster.copyToPasteboard(plain: content, representations: nil)
            statusMessage = "Snippet copied to clipboard"
            dismissStatus()
        }
    }

    private func dismissStatus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.statusMessage = nil
        }
    }

    // MARK: - Keyboard Navigation

    public func selectNext() {
        let list = filteredSnippets
        guard !list.isEmpty else { return }
        if let current = selectedSnippet, let idx = list.firstIndex(where: { $0.id == current.id }) {
            let nextIdx = min(idx + 1, list.count - 1)
            selectedSnippet = list[nextIdx]
        } else {
            selectedSnippet = list.first
        }
    }

    public func selectPrevious() {
        let list = filteredSnippets
        guard !list.isEmpty else { return }
        if let current = selectedSnippet, let idx = list.firstIndex(where: { $0.id == current.id }) {
            let prevIdx = max(idx - 1, 0)
            selectedSnippet = list[prevIdx]
        } else {
            selectedSnippet = list.last
        }
    }

    public func triggerSelectedItem(onClose: () -> Void) {
        let target = selectedSnippet ?? filteredSnippets.first
        guard let snippet = target else { return }
        onClose()
        triggerSnippet(snippet)
    }

    public func deleteSelectedItem() {
        guard let current = selectedSnippet else { return }
        let list = filteredSnippets
        if let idx = list.firstIndex(where: { $0.id == current.id }) {
            deleteSnippet(id: current.id)
            let updated = filteredSnippets
            if !updated.isEmpty {
                let nextIdx = min(idx, updated.count - 1)
                selectedSnippet = updated[nextIdx]
            } else {
                selectedSnippet = nil
            }
        }
    }
}
