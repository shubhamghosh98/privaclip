import SwiftUI
import PrivaClipCore

/// Horizontal scrolling bar of Smart Collection filter pills.
public struct SmartCollectionFilterChips: View {
    @Binding public var selectedTag: SmartCollectionTag

    public init(selectedTag: Binding<SmartCollectionTag>) {
        self._selectedTag = selectedTag
    }

    private let tags: [SmartCollectionTag] = [
        .all, .links, .code, .emails, .phones, .colors, .images
    ]

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags) { tag in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTag = tag
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: tag.iconName)
                                .font(.system(size: 10))
                            Text(tag.rawValue)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(selectedTag == tag ? Color.accentColor : Color.secondary.opacity(0.12))
                        )
                        .foregroundColor(selectedTag == tag ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }
}
