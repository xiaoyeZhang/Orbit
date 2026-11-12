import SwiftUI

/// A navigation/control surface, with an opaque accessibility fallback.
public struct OrbitGlassSurface<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let shape: S
    private let tint: Color?
    private let interactive: Bool

    public init(shape: S, tint: Color? = nil, interactive: Bool = false) {
        self.shape = shape
        self.tint = tint
        self.interactive = interactive
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Theme.Palette.card, in: shape)
                .overlay(shape.stroke(Theme.Palette.separator, lineWidth: 0.5))
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Theme.Palette.separator.opacity(0.6), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
    }
}

public extension View {
    func orbitGlass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(OrbitGlassSurface(shape: shape, tint: tint, interactive: interactive))
    }
}

/// Nearby controls share one glass rendering container on supported systems.
public struct OrbitGlassGroup<Content: View>: View {
    private let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    @ViewBuilder public var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 12) { content }
        } else {
            content
        }
    }
}
