import SwiftUI
import AppKit
import PrivaClipCore

/// Comprehensive preferences window supporting general settings, hotkeys, exclusions, and encrypted backups.
public struct PreferencesView: View {
    @ObservedObject public var historyVM: HistoryViewModel
    @ObservedObject public var snippetsVM: SnippetsViewModel
    @StateObject public var prefVM = PreferencesViewModel()

    public init(historyVM: HistoryViewModel, snippetsVM: SnippetsViewModel) {
        self.historyVM = historyVM
        self.snippetsVM = snippetsVM
    }

    public var body: some View {
        TabView(selection: $prefVM.selectedTab) {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
                .tag(0)

            exclusionsTab
                .tabItem { Label("Exclusions", systemImage: "hand.raised") }
                .tag(1)

            backupTab
                .tabItem { Label("Backup & Privacy", systemImage: "lock.shield") }
                .tag(2)

            proTab
                .tabItem { Label("Pro Vault", systemImage: "star.fill") }
                .tag(3)
        }
        .padding(20)
        .frame(width: 480, height: 360)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("History Limits") {
                Picker("Max Unpinned Items:", selection: $prefVM.historySize) {
                    ForEach(AppPreferences.historySizePresets, id: \.self) { size in
                        Text("\(size) items").tag(size)
                    }
                }
                .onChange(of: prefVM.historySize) { _, newValue in
                    prefVM.updateHistorySize(newValue)
                }
                Text("Pinned items are kept indefinitely and not counted against this limit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup & Behavior") {
                Toggle("Launch at Login", isOn: $prefVM.launchAtLogin)
                    .onChange(of: prefVM.launchAtLogin) { _, newValue in
                        prefVM.updateLaunchAtLogin(newValue)
                    }

                Toggle("Auto-paste on selection", isOn: $prefVM.autoPaste)
                    .onChange(of: prefVM.autoPaste) { _, newValue in
                        prefVM.updateAutoPaste(newValue)
                    }
            }

            Section("Default Shortcut") {
                HStack {
                    Text("Global Hotkey:")
                    Spacer()
                    Text("⌥V (Option + V)")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    // MARK: - Exclusions Tab

    private var exclusionsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Exclude Applications from History")
                .font(.headline)
            Text("Copies from these apps will be completely ignored and never stored.")
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                ForEach(prefVM.excludedApps, id: \.self) { bundleID in
                    HStack {
                        Text(bundleID)
                            .font(.system(size: 12, design: .monospaced))
                        Spacer()
                        Button(action: { prefVM.removeExcludedApp(bundleID) }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 140)
            .border(Color.secondary.opacity(0.2))

            HStack {
                TextField("com.example.app", text: $prefVM.newExcludedBundle)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    prefVM.addExcludedApp()
                }
                .disabled(prefVM.newExcludedBundle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Backup & Security Tab

    private var backupTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("At-Rest Encryption & Backup")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Label("AES-GCM-256 Authenticated Encryption", systemImage: "checkmark.shield.fill")
                    .foregroundColor(.green)
                Label("Hardware Keychain Key (Non-synchronizing)", systemImage: "key.fill")
                    .foregroundColor(.green)
                Label("Zero Outbound Network or Telemetry", systemImage: "network.slash")
                    .foregroundColor(.green)
            }
            .font(.caption)

            Divider()

            Text("Encrypted Backup Archive (.privaclip)")
                .font(.subheadline.bold())

            SecureField("Passphrase for export/restore", text: $prefVM.backupPassphrase)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Export Encrypted Archive…") {
                    performExport()
                }
                .disabled(prefVM.backupPassphrase.isEmpty)

                Button("Import from Archive…") {
                    performImport()
                }
                .disabled(prefVM.backupPassphrase.isEmpty)
            }

            if let msg = prefVM.backupStatusMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }

            Spacer()
        }
    }

    private func performExport() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.data]
        savePanel.nameFieldStringValue = "PrivaClip_Backup_\(Int(Date().timeIntervalSince1970)).privaclip"
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try BackupService.exportArchive(
                    items: historyVM.items,
                    snippets: snippetsVM.snippets,
                    password: prefVM.backupPassphrase,
                    destinationURL: url
                )
                prefVM.backupStatusMessage = "Successfully exported to \(url.lastPathComponent)"
            } catch {
                prefVM.backupStatusMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    private func performImport() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.data]
        openPanel.allowsMultipleSelection = false
        if openPanel.runModal() == .OK, let url = openPanel.url {
            do {
                let (items, snippets) = try BackupService.importArchive(
                    sourceURL: url,
                    password: prefVM.backupPassphrase
                )
                for item in items {
                    historyVM.addCapturedContent(.text(
                        plain: item.text,
                        richReps: item.richRepresentations,
                        bundleID: item.sourceBundleID,
                        appName: item.sourceAppName
                    ))
                }
                for s in snippets {
                    snippetsVM.addSnippet(title: s.title, content: s.content, category: s.category, tags: s.tags)
                }
                prefVM.backupStatusMessage = "Restored \(items.count) items & \(snippets.count) snippets."
            } catch {
                prefVM.backupStatusMessage = "Import failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Pro Tab

    private var proTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
                Text("PrivaClip Pro Vault")
                    .font(.headline)
            }

            Text("Pro unlocks differentiated workflow enhancements while keeping the core clipboard 100% free and private.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Label("Smart Collections (Links, Code, Emails, Phones)", systemImage: "tray.2.fill")
                Label("Reusable Snippet Library & Placeholders", systemImage: "doc.text.fill")
                Label("Application Exclusion Rules", systemImage: "hand.raised.fill")
                Label("Password-Protected Encrypted Archives", systemImage: "lock.shield.fill")
            }
            .font(.caption)

            Divider()

            Toggle("Pro Features Enabled (Test Entitlement)", isOn: $prefVM.isProUnlocked)
                .onChange(of: prefVM.isProUnlocked) { _, val in
                    prefVM.updateProUnlocked(val)
                }

            Spacer()
        }
    }
}
