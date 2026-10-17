import SwiftUI
import AppKit

/// Design tokens, typography, and styling constants for PrivaClip.
public enum PrivaClipTheme {
    public static let panelWidth: CGFloat = 360
    public static let panelHeight: CGFloat = 520
    public static let cornerRadius: CGFloat = 14
    public static let rowCornerRadius: CGFloat = 9

    public static let innerPadding: CGFloat = 10
    public static let outerPadding: CGFloat = 12

    // Accent and status colors
    public static let accentColor = Color.accentColor
    public static let cardBackground = Color(NSColor.controlBackgroundColor).opacity(0.6)
    public static let borderStroke = Color.white.opacity(0.08)
    public static let secondaryBorderStroke = Color.white.opacity(0.04)

    public static let hoverBackground = Color.primary.opacity(0.06)
    public static let selectedBackground = Color.accentColor.opacity(0.18)
    public static let multiSelectedBackground = Color.accentColor.opacity(0.25)
}

/// AppKit VisualEffectView bridge for macOS liquid-glass materials.
public struct VisualEffectView: NSViewRepresentable {
    public let material: NSVisualEffectView.Material
    public let blendingMode: NSVisualEffectView.BlendingMode
    public let isEmphasized: Bool

    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .withinWindow,
        isEmphasized: Bool = true
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.isEmphasized = isEmphasized
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = isEmphasized
        view.wantsLayer = true
        view.layer?.cornerRadius = PrivaClipTheme.cornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
        nsView.isEmphasized = isEmphasized
    }
}
