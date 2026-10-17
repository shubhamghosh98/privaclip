import SwiftUI
import AppKit
import PrivaClipCore

/// The main floating panel UI combining history, search, smart collections, and snippet library.
public struct HistoryPanelView: View {
    @ObservedObject public var historyVM: HistoryViewModel
    @ObservedObject public var snippetsVM: SnippetsViewModel
    public var onClose: () -> Void
    public var onOpenPreferences: () -> Void

    public init(
        historyVM: HistoryViewModel,
        snippetsVM: SnippetsViewModel,
        onClose: @escaping () -> Void,
        onOpenPreferences: @escaping () -> Void
    ) {
        self.historyVM = historyVM
        self.snippetsVM = snippetsVM
        self.onClose = onClose
        self.onOpenPreferences = onOpenPreferences
    }

    public var body: some View {
        ZStack(alignment: .top) {
            VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                .clipShape(RoundedRectangle(cornerRadius: PrivaClipTheme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PrivaClipTheme.cornerRadius, style: .continuous)
                        .strokeBorder(PrivaClipTheme.borderStroke, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 3)

            VStack(spacing: 8) {
                // Top control bar (Tab switcher & Preferences gear)
                topControlBar

                // Search Bar
                searchBar

                // Secondary controls / Smart tags
                if historyVM.selectedTab == .history {
                    SmartCollectionFilterChips(selectedTag: $historyVM.selectedTag)
                }

                // Accessibility Permission Banner
                if !historyVM.accessibilityGranted {
                    accessibilityWarningBanner
                }

                // Main content
                if historyVM.selectedTab == .history {
                    historyListView
                } else {
                    SnippetPickerView(snippetsVM: snippetsVM)
                }

                // Status Toast
                if let status = historyVM.statusMessage ?? snippetsVM.statusMessage {
                    statusToast(status)
                }

                // Bottom bar
                bottomBar
            }
            .padding(PrivaClipTheme.innerPadding)
        }
        .frame(width: PrivaClipTheme.panelWidth, height: PrivaClipTheme.panelHeight)
        .confirmationDialog(
            historyVM.clearAllIncludingPinned ? "Clear entire clipboard history, including pinned items?" : "Clear all unpinned clipboard items?",
            isPresented: $historyVM.showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(historyVM.clearAllIncludingPinned ? "Clear Everything" : "Clear Unpinned", role: .destructive) {
                historyVM.clearHistory(removePinned: historyVM.clearAllIncludingPinned)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(historyVM.clearAllIncludingPinned
                 ? "This permanently deletes every history item and its encrypted image data. This action cannot be undone."
                 : "This permanently deletes all unpinned history items. Pinned items will be preserved.")
        }
    }

    // MARK: - Subviews

    private var topControlBar: some View {
        HStack {
            Picker("Mode", selection: $historyVM.selectedTab) {
                ForEach(PanelTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(maxWidth: 160)

            Spacer()

            Button(action: onOpenPreferences) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open Preferences")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField(
                historyVM.selectedTab == .history ? "Search clipboard history…" : "Search snippets…",
                text: historyVM.selectedTab == .history ? $historyVM.searchText : $snippetsVM.searchText
            )
            .textFieldStyle(.plain)

            if !(historyVM.selectedTab == .history ? historyVM.searchText : snippetsVM.searchText).isEmpty {
                Button(action: {
                    if historyVM.selectedTab == .history {
                        historyVM.searchText = ""
                    } else {
                        snippetsVM.searchText = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if historyVM.isMultiSelectMode {
                Button("Done") {
                    historyVM.exitMultiSelectMode()
                }
                .controlSize(.small)

                Button(role: .destructive) {
                    historyVM.deleteSelected()
                } label: {
                    Text("Delete (\(historyVM.selectedIDs.count))")
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
                .disabled(historyVM.selectedIDs.isEmpty)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var accessibilityWarningBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 12))
            Text("Accessibility permission needed for auto-paste.")
                .font(.system(size: 11))
                .foregroundColor(.primary)
            Spacer()
            Button("Settings") {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
            .controlSize(.mini)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }

    private var historyListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    let pinned = historyVM.pinnedFilteredItems
                    if !pinned.isEmpty {
                        HStack {
                            Label("PINNED", systemImage: "pin.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.top, 4)
                        .padding(.horizontal, 4)

                        ForEach(pinned) { item in
                            ClipRowView(
                                item: item,
                                isSelected: historyVM.selectedID == item.id,
                                isMultiSelected: historyVM.selectedIDs.contains(item.id),
                                isMultiSelectMode: historyVM.isMultiSelectMode,
                                previewItemID: $historyVM.previewItemID,
                                onTap: {
                                    if historyVM.isMultiSelectMode {
                                        historyVM.toggleMultiSelect(item.id)
                                    } else {
                                        historyVM.selectedID = item.id
                                        onClose()
                                        historyVM.pasteItem(item)
                                    }
                                },
                                onTogglePin: { historyVM.togglePin(item.id) },
                                onDelete: { historyVM.deleteItem(item.id) },
                                onCopyOnly: {
                                    onClose()
                                    historyVM.copyItemOnly(item)
                                }
                            )
                            .id(item.id)
                        }

                        Divider()
                            .padding(.vertical, 4)
                    }

                    let unpinned = historyVM.unpinnedFilteredItems
                    if unpinned.isEmpty && pinned.isEmpty {
                        emptyState
                    } else {
                        ForEach(unpinned) { item in
                            ClipRowView(
                                item: item,
                                isSelected: historyVM.selectedID == item.id,
                                isMultiSelected: historyVM.selectedIDs.contains(item.id),
                                isMultiSelectMode: historyVM.isMultiSelectMode,
                                previewItemID: $historyVM.previewItemID,
                                onTap: {
                                    if historyVM.isMultiSelectMode {
                                        historyVM.toggleMultiSelect(item.id)
                                    } else {
                                        historyVM.selectedID = item.id
                                        onClose()
                                        historyVM.pasteItem(item)
                                    }
                                },
                                onTogglePin: { historyVM.togglePin(item.id) },
                                onDelete: { historyVM.deleteItem(item.id) },
                                onCopyOnly: {
                                    onClose()
                                    historyVM.copyItemOnly(item)
                                }
                            )
                            .id(item.id)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .onChange(of: historyVM.selectedID) { _, newID in
                guard let newID else { return }
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
        .onAppear {
            if historyVM.selectedID == nil {
                historyVM.selectedID = historyVM.filteredItems.first?.id
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
            Text(historyVM.searchText.isEmpty ? "Clipboard is empty" : "No matching items found")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity)
    }

    private func statusToast(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 12))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color(NSColor.windowBackgroundColor).opacity(0.95)))
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
        .transition(.opacity.combined(with: .scale))
    }

    private var bottomBar: some View {
        HStack {
            if historyVM.selectedTab == .history && !historyVM.isMultiSelectMode {
                Button(role: .destructive) {
                    historyVM.clearAllIncludingPinned = NSEvent.modifierFlags.contains(.option)
                    historyVM.showingClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                    Text("Clear")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear unpinned history (⌥-click to clear all including pinned)")
            }

            Spacer()

            Text("\(historyVM.items.count) items")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 3) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 10))
                Text("AES-256")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary.opacity(0.8))
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }
}
