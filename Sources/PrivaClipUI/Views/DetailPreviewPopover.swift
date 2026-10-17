import SwiftUI
import AppKit
import PrivaClipCore

/// Popover displaying full text or full-resolution image preview.
public struct DetailPreviewPopover: View {
    public let item: ClipItem

    public init(item: ClipItem) {
        self.item = item
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if item.isImage, let fn = item.imageFileName {
                imageContent(fileName: fn)
            } else {
                textContent
            }
        }
        .padding(12)
        .frame(minWidth: 320, maxWidth: 500, minHeight: 180, maxHeight: 400)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.sourceAppName ?? "Text")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(item.characterCount) characters")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                Text(item.text)
                    .textSelection(.enabled)
                    .font(.system(.body, design: item.smartTags.contains(.code) ? .monospaced : .default))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func imageContent(fileName: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.sourceAppName ?? "Image")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if let w = item.imageWidth, let h = item.imageHeight {
                    Text("\(w) × \(h) px")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let img = ImageVault.shared.loadFullImage(fileName: fileName) {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 340)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
