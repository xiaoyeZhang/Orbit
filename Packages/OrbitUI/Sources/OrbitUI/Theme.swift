import SwiftUI

public enum Theme {

    public enum Palette {
        public static let primary      = Color(hex: 0x6C5CE7)
        public static let primaryDark  = Color(hex: 0x4834D4)
        public static let accent       = Color(hex: 0xFD79A8)
        public static let sunshine     = Color(hex: 0xFDCB6E)
        public static let mint         = Color(hex: 0x00D2A8)
        public static let sky          = Color(hex: 0x54A0FF)
        public static let danger       = Color(hex: 0xFF6B6B)
        public static let online       = Color(hex: 0x2ECC71)
        public static let ink          = Color(.label)
        public static let subtle       = Color(.secondaryLabel)
        public static let surface      = Color(.systemBackground)
        public static let groupedBackground = Color(.systemGroupedBackground)

        // Dark-first palette
        public static let bg           = Color(hex: 0x0D0D0D)
        public static let card         = Color(hex: 0x1C1C1E)
        public static let card2        = Color(hex: 0x2C2C2E)
        public static let separator    = Color(white: 1.0, opacity: 0.08)
        public static let textPrimary  = Color.white
        public static let textSecondary = Color(white: 1.0, opacity: 0.50)
    }

    public static var brandGradient: LinearGradient {
        LinearGradient(colors: [Palette.primary, Palette.accent],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    public static var skyGradient: LinearGradient {
        LinearGradient(colors: [Palette.sky, Palette.mint], startPoint: .top, endPoint: .bottom)
    }
    public static var sunsetGradient: LinearGradient {
        LinearGradient(colors: [Palette.accent, Palette.sunshine],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    public static var oceanGradient: LinearGradient {
        LinearGradient(colors: [Palette.mint, Palette.sky],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    public static var deepGradient: LinearGradient {
        LinearGradient(colors: [Palette.primaryDark, Palette.primary, Palette.accent],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    public enum Metric {
        public static let corner: CGFloat      = 20
        public static let smallCorner: CGFloat = 12
        public static let cardPadding: CGFloat = 16
        public static let avatar: CGFloat      = 52
    }
}

public extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red:     Double((hex >> 16) & 0xff) / 255,
                  green:   Double((hex >> 08) & 0xff) / 255,
                  blue:    Double((hex >> 00) & 0xff) / 255,
                  opacity: alpha)
    }
}

// MARK: - Card modifiers
public struct CardBackground: ViewModifier {
    var fill: Color
    public init(fill: Color = Theme.Palette.surface) { self.fill = fill }
    public func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: Theme.Metric.corner, style: .continuous).fill(fill))
            .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 5)
    }
}

public extension View {
    func card(_ fill: Color = Theme.Palette.surface) -> some View {
        modifier(CardBackground(fill: fill))
    }
    func darkCard() -> some View {
        modifier(CardBackground(fill: Theme.Palette.card))
    }
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
    func gradientCard<S: ShapeStyle>(_ gradient: S, cornerRadius: CGFloat = 20) -> some View {
        modifier(GradientCard(gradient: AnyShapeStyle(gradient), cornerRadius: cornerRadius))
    }
}

public struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat
    public init(cornerRadius: CGFloat = 20) { self.cornerRadius = cornerRadius }
    public func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(.white.opacity(0.28), lineWidth: 0.8)
                    }
            }
            .shadow(color: .black.opacity(0.10), radius: 20, y: 8)
    }
}

public struct GradientCard: ViewModifier {
    let gradient: AnyShapeStyle
    var cornerRadius: CGFloat
    public init(gradient: AnyShapeStyle, cornerRadius: CGFloat = 20) {
        self.gradient = gradient; self.cornerRadius = cornerRadius
    }
    public func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(gradient))
            .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }
}
