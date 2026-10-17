import SwiftUI
import Combine
import PrivaClipCore

public enum PanelTab: String, CaseIterable, Identifiable, Sendable {
    case history = "History"
    case snippets = "Snippets"

    public var id: String { rawValue }
}

/// Main-actor view model managing clipboard history, filtering, smart tags, and user actions.
@MainActor
public final class HistoryViewModel: ObservableObject {
    @Published public private(set) var items: [ClipItem] = []
    @Published public var searchText: String = ""
    @Published public var selectedTag: SmartCollectionTag = .all
    @Published public var selectedTab: PanelTab = .history
    @Published public var selectedID: UUID?
    @Published public var previewItemID: UUID?
    @Published public var isMultiSelectMode: Bool = false
    @Published public var selectedIDs: Set<UUID> = []
    @Published public var statusMessage: String?
    @Published public var accessibilityGranted: Bool = true

    // Confirmation dialog state
    @Published public var showingClearConfirmation: Bool = false
    @Published public var clearAllIncludingPinned: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private let saveSubject = PassthroughSubject<Void, Never>()

    public init() {
        // 1. Load persisted history
        self.items = PersistenceManager.shared.loadHistory()

        // 2. Prune orphaned images
        let referencedImages = Set(items.compactMap { $0.imageFileName })
        ImageVault.shared.pruneOrphans(referenced: referencedImages)

        // 3. Debounced save (300ms)
        saveSubject
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                PersistenceManager.shared.saveHistory(items: self.items)
            }
            .store(in: &cancellables)

        // 4. Listen for history size preference changes
        NotificationCenter.default.addObserver(
            forName: AppPreferences.historySizeChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.trimHistory()
                self.scheduleSave()
            }
        }

        // Initial accessibility check
        self.accessibilityGranted = AutoPaster.checkAccessibilityTrust()
    }

    public func scheduleSave() {
        saveSubject.send(())
    }

    // MARK: - Adding Items

    public func addCapturedContent(_ content: CapturedContent) {
        switch content {
        case let .text(plain, richReps, bundleID, appName):
            addTextItem(plain: plain, richReps: richReps, bundleID: bundleID, appName: appName)
        case let .image(pngData, width, height, bundleID, appName):
            addImageItem(pngData: pngData, width: width, height: height, bundleID: bundleID, appName: appName)
        }
    }

    private func addTextItem(
        plain: String,
        richReps: [String: Data]?,
        bundleID: String?,
        appName: String?
    ) {
        let trimmed = plain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let existingIdx = items.firstIndex(where: { !$0.isImage && $0.text == plain }) {
            var existing = items.remove(at: existingIdx)
            existing.date = Date()
            existing.sourceBundleID = bundleID ?? existing.sourceBundleID
            existing.sourceAppName = appName ?? existing.sourceAppName
            existing.richRepresentations = richReps ?? existing.richRepresentations
            items.insert(existing, at: 0)
            scheduleSave()
            return
        }

        var tags = SmartClassifier.classify(text: plain)
        if !tags.isEmpty {
            tags.insert(.all)
        }

        let newItem = ClipItem(
            id: UUID(),
            kind: (richReps != nil && !richReps!.isEmpty) ? .richText : .text,
            text: plain,
            date: Date(),
            pinned: false,
            sourceBundleID: bundleID,
            sourceAppName: appName,
            richRepresentations: richReps,
            smartTags: tags
        )

        items.insert(newItem, at: 0)
        trimHistory()
        scheduleSave()
    }

    private func addImageItem(
        pngData: Data,
        width: Int,
        height: Int,
        bundleID: String?,
        appName: String?
    ) {
        let hash = CryptoService.sha256Hex(pngData)

        if let existingIdx = items.firstIndex(where: { $0.imageHash == hash }) {
            var existing = items.remove(at: existingIdx)
            existing.date = Date()
            existing.sourceBundleID = bundleID ?? existing.sourceBundleID
            existing.sourceAppName = appName ?? existing.sourceAppName
            items.insert(existing, at: 0)
            scheduleSave()
            return
        }

        let id = UUID()
        let fileName = "\(id.uuidString).imgenc"
        ImageVault.shared.save(pngData: pngData, fileName: fileName)

        let newItem = ClipItem(
            id: id,
            kind: .image,
            text: "Image (\(width) × \(height))",
            date: Date(),
            pinned: false,
            imageFileName: fileName,
            imageWidth: width,
            imageHeight: height,
            imageHash: hash,
            sourceBundleID: bundleID,
            sourceAppName: appName,
            smartTags: [.images, .all]
        )

        items.insert(newItem, at: 0)
        trimHistory()
        scheduleSave()
    }

    // MARK: - Actions

    public func togglePin(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].pinned.toggle()
        trimHistory()
        scheduleSave()
    }

    public func deleteItem(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items.remove(at: idx)
        if item.isImage, let fn = item.imageFileName {
            ImageVault.shared.delete(fileName: fn)
        }
        if selectedID == id { selectedID = nil }
        if previewItemID == id { previewItemID = nil }
        selectedIDs.remove(id)
        scheduleSave()
    }

    public func deleteSelected() {
        let idsToDelete = selectedIDs
        for id in idsToDelete {
            deleteItem(id)
        }
        exitMultiSelectMode()
    }

    public func clearHistory(removePinned: Bool = false) {
        if removePinned {
            for item in items where item.isImage {
                if let fn = item.imageFileName { ImageVault.shared.delete(fileName: fn) }
            }
            items.removeAll()
        } else {
            let unpinned = items.filter { !$0.pinned }
            for item in unpinned where item.isImage {
                if let fn = item.imageFileName { ImageVault.shared.delete(fileName: fn) }
            }
            items.removeAll(where: { !$0.pinned })
        }
        selectedID = nil
        previewItemID = nil
        selectedIDs.removeAll()
        showingClearConfirmation = false
        scheduleSave()
    }

    public func pasteItem(_ item: ClipItem) {
        AutoPaster.paste(item: item) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .pastedSuccessfully:
                    self.statusMessage = "Pasted into active app"
                case .clipboardOnlyAccessibilityDenied:
                    self.accessibilityGranted = false
                    self.statusMessage = "Copied to Clipboard — Press ⌘V to Paste"
                case .clipboardOnlyNoTargetApp:
                    self.statusMessage = "Copied to Clipboard"
                case .targetAppDidNotActivate:
                    self.statusMessage = "Copied to Clipboard (app did not activate)"
                }
                self.scheduleStatusDismiss()
            }
        }
    }

    public func copyItemOnly(_ item: ClipItem) {
        AutoPaster.copyOnly(item: item)
        statusMessage = "Copied to Clipboard"
        scheduleStatusDismiss()
    }

    private func scheduleStatusDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.statusMessage = nil
        }
    }

    // MARK: - Selection Mode

    public func enterMultiSelectMode(initialID: UUID? = nil) {
        isMultiSelectMode = true
        if let id = initialID {
            selectedIDs = [id]
        } else {
            selectedIDs.removeAll()
        }
        previewItemID = nil
    }

    public func exitMultiSelectMode() {
        isMultiSelectMode = false
        selectedIDs.removeAll()
    }

    public func toggleMultiSelect(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    // MARK: - Trimming

    private func trimHistory() {
        let limit = AppPreferences.shared.historySize
        let unpinned = items.filter { !$0.pinned }
        if unpinned.count > limit {
            let toRemove = Array(unpinned.dropFirst(limit))
            let toRemoveIDs = Set(toRemove.map { $0.id })
            for item in toRemove where item.isImage {
                if let fn = item.imageFileName { ImageVault.shared.delete(fileName: fn) }
            }
            items.removeAll(where: { toRemoveIDs.contains($0.id) })
        }
    }

    // MARK: - Filtered Items

    public var filteredItems: [ClipItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { item in
            if !query.isEmpty {
                let matchesText = item.text.localizedCaseInsensitiveContains(query)
                let matchesApp = item.sourceAppName?.localizedCaseInsensitiveContains(query) ?? false
                guard matchesText || matchesApp else { return false }
            }

            if selectedTag != .all {
                if selectedTag == .images && !item.isImage { return false }
                if selectedTag != .images && !item.smartTags.contains(selectedTag) { return false }
            }

            return true
        }
    }

    public var pinnedFilteredItems: [ClipItem] {
        filteredItems.filter { $0.pinned }
    }

    public var unpinnedFilteredItems: [ClipItem] {
        filteredItems.filter { !$0.pinned }
    }
}
