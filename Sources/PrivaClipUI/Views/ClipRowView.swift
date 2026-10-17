import SwiftUI
import AppKit
import PrivaClipCore

/// Component rendering a single clipboard item row with metadata, tags, and actions.
public struct ClipRowView: View {
    public let item: ClipItem
    public let isSelected: Bool
    public let isMultiSelected: Bool
    public let isMultiSelectMode: Bool
    public let onTap: () -> Void
    public let onTogglePin: () -> Void
    public let onDelete: () -> Void
    public let onCopyOnly: () -> Void

    @Binding public var previewItemID: UUID?

    public init(
        item: ClipItem,
        isSelected: Bool,
        isMultiSelected: Bool,
        isMultiSelectMode: Bool,
        previewItemID: Binding<UUID?>,
        onTap: @escaping () -> Void,
        onTogglePin: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onCopyOnly: @escaping () -> Void
    ) {
        self.item = item
        self.isSelected = isSelected
        self.isMultiSelected = isMultiSelected
        self.isMultiSelectMode = isMultiSelectMode
        self._previewItemID = previewItemID
        self.onTap = onTap
        self.onTogglePin = onTogglePin
        self.onDelete = onDelete
        self.onCopyOnly = onCopyOnly
    }

    private var isPreviewing: Binding<Bool> {
        Binding(
            get: { previewItemID == item.id },
            set: { show in
                previewItemID = show ? item.id : nil
            }
        )
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Selection checkbox (in multi-select mode)
            if isMultiSelectMode {
                Image(systemName: isMultiSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isMultiSelected ? .accentColor : .secondary)
                    .font(.system(size: 14))
            }

            // Main item representation
            VStack(alignment: .leading, spacing: 4) {
                mainContent
                metaContent
            }

            Spacer(minLength: 4)

            // Trailing actions
            trailingButtons
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: PrivaClipTheme.rowCornerRadius, style: .continuous)
                .fill(rowBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PrivaClipTheme.rowCornerRadius, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.white.opacity(0.04), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button(item.pinned ? "Unpin Item" : "Pin Item", action: onTogglePin)
            Button("Copy Only (No Paste)", action: onCopyOnly)
            Divider()
            Button("Delete Item", role: .destructive, action: onDelete)
        }
        .popover(isPresented: isPreviewing, arrowEdge: .trailing) {
            DetailPreviewPopover(item: item)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if item.isImage, let fn = item.imageFileName {
            imageThumbnail(fileName: fn)
        } else {
            Text(item.text)
                .lineLimit(2)
                .truncationMode(.tail)
                .font(.system(size: 13, design: item.smartTags.contains(.code) ? .monospaced : .default))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func imageThumbnail(fileName: String) -> some View {
        HStack(spacing: 6) {
            if let thumb = ImageVault.shared.loadThumbnail(fileName: fileName, maxPixelSize: 200) {
                Image(nsImage: thumb)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 64, height: 48)
                    .overlay(Image(systemName: "photo").foregroundColor(.secondary))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayTitle)
                    .font(.system(size: 12, weight: .medium))
                if let w = item.imageWidth, let h = item.imageHeight {
                    Text("\(w) × \(h) px")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var metaContent: some View {
        HStack(spacing: 5) {
            if let appIcon = iconForBundle(item.sourceBundleID) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 12, height: 12)
            }

            if let appName = item.sourceAppName, !appName.isEmpty {
                Text(appName)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
                Text("•")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary.opacity(0.6))
            }

            Text(formattedDate(item.date))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            ForEach(Array(item.smartTags.filter { $0 != .all }), id: \.self) { tag in
                Text(tag.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var trailingButtons: some View {
        HStack(spacing: 4) {
            Button(action: onTogglePin) {
                Image(systemName: item.pinned ? "pin.fill" : "pin")
                    .font(.system(size: 12))
                    .foregroundColor(item.pinned ? .accentColor : .secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .help(item.pinned ? "Unpin item" : "Pin item")

            Button(action: {
                previewItemID = (previewItemID == item.id) ? nil : item.id
            }) {
                Image(systemName: "eye")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help("Preview full item")
        }
    }

    private var rowBackgroundColor: Color {
        if isMultiSelected { return PrivaClipTheme.multiSelectedBackground }
        if isSelected { return PrivaClipTheme.selectedBackground }
        return Color.clear
    }

    private func iconForBundle(_ bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            return app.icon
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
