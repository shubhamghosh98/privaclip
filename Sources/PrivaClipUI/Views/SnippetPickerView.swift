import SwiftUI
import PrivaClipCore

/// View for browsing, creating, and expanding reusable text snippets.
public struct SnippetPickerView: View {
    @ObservedObject public var snippetsVM: SnippetsViewModel

    public init(snippetsVM: SnippetsViewModel) {
        self.snippetsVM = snippetsVM
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Category & Add bar
            HStack {
                Picker("Category", selection: $snippetsVM.selectedCategory) {
                    ForEach(snippetsVM.categories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(maxWidth: 140)

                Spacer()

                Button(action: { snippetsVM.showingAddSheet = true }) {
                    Label("New Snippet", systemImage: "plus")
                        .font(.caption)
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 4)

            // Snippets list
            if snippetsVM.filteredSnippets.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No snippets found")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(snippetsVM.filteredSnippets) { snippet in
                            snippetRow(snippet)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .sheet(isPresented: $snippetsVM.showingAddSheet) {
            addSnippetSheet
        }
        .sheet(isPresented: Binding(
            get: { snippetsVM.activePlaceholderSnippet != nil },
            set: { show in if !show { snippetsVM.cancelPlaceholderSnippet() } }
        )) {
            placeholderExpansionSheet
        }
    }

    private func snippetRow(_ snippet: Snippet) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(snippet.title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(snippet.category)
                        .font(.system(size: 9))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
                Text(snippet.content)
                    .lineLimit(2)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: {
                snippetsVM.triggerSnippet(snippet, pasteDirectly: true)
            }) {
                Image(systemName: "arrow.right.doc.on.clipboard")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Insert snippet into active app")
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            snippetsVM.triggerSnippet(snippet, pasteDirectly: true)
        }
        .contextMenu {
            Button("Copy to Clipboard") {
                snippetsVM.triggerSnippet(snippet, pasteDirectly: false)
            }
            Divider()
            Button("Delete Snippet", role: .destructive) {
                snippetsVM.deleteSnippet(id: snippet.id)
            }
        }
    }

    private var addSnippetSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create New Snippet")
                .font(.headline)

            TextField("Title", text: $snippetsVM.newTitle)
                .textFieldStyle(.roundedBorder)

            TextField("Category", text: $snippetsVM.newCategory)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 4) {
                Text("Snippet Body (use {variable} for placeholders):")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $snippetsVM.newContent)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 100)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.2)))
            }

            HStack {
                Button("Cancel") {
                    snippetsVM.showingAddSheet = false
                    snippetsVM.newTitle = ""
                    snippetsVM.newContent = ""
                }
                Spacer()
                Button("Save") {
                    guard !snippetsVM.newTitle.isEmpty, !snippetsVM.newContent.isEmpty else { return }
                    snippetsVM.addSnippet(
                        title: snippetsVM.newTitle,
                        content: snippetsVM.newContent,
                        category: snippetsVM.newCategory
                    )
                    snippetsVM.showingAddSheet = false
                    snippetsVM.newTitle = ""
                    snippetsVM.newContent = ""
                }
                .disabled(snippetsVM.newTitle.isEmpty || snippetsVM.newContent.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 380, height: 280)
    }

    private var placeholderExpansionSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fill Snippet Placeholders")
                .font(.headline)

            if let snippet = snippetsVM.activePlaceholderSnippet {
                Text(snippet.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(snippet.placeholders, id: \.self) { placeholder in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(placeholder.capitalized)
                                    .font(.caption.bold())
                                TextField(
                                    placeholder,
                                    text: Binding(
                                        get: { snippetsVM.placeholderValues[placeholder] ?? "" },
                                        set: { snippetsVM.placeholderValues[placeholder] = $0 }
                                    )
                                )
                                .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                }
                .frame(maxHeight: 180)
            }

            HStack {
                Button("Cancel") {
                    snippetsVM.cancelPlaceholderSnippet()
                }
                Spacer()
                Button("Insert Snippet") {
                    snippetsVM.submitPlaceholderSnippet(pasteDirectly: true)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 360, height: 260)
    }
}
