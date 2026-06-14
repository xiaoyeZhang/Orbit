import SwiftUI

enum Theme {

    // MARK: - Colors
    enum Palette {
        static let primary      = Color(hex: 0x6C5CE7)
        static let primaryDark  = Color(hex: 0x4834D4)
        static let accent       = Color(hex: 0xFD79A8)
        static let sunshine     = Color(hex: 0xFDCB6E)
        static let mint         = Color(hex: 0x00D2A8)
        static let sky          = Color(hex: 0x54A0FF)
        static let danger       = Color(hex: 0xFF6B6B)
        static let online       = Color(hex: 0x2ECC71)
        static let ink          = Color(.label)
        static let subtle       = Color(.secondaryLabel)
        static let surface      = Color(.systemBackground)
        static let groupedBackground = Color(.systemGroupedBackground)
    }

    // MARK: - Gradients
    static var brandGradient: LinearGradient {
        LinearGradient(colors: [Palette.primary, Palette.accent],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var skyGradient: LinearGradient {
        LinearGradient(colors: [Palette.sky, Palette.mint],
                       startPoint: .top, endPoint: .bottom)
    }

    static var sunsetGradient: LinearGradient {
        LinearGradient(colors: [Palette.accent, Palette.sunshine],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var oceanGradient: LinearGradient {
        LinearGradient(colors: [Palette.mint, Palette.sky],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var deepGradient: LinearGradient {
        LinearGradient(colors: [Palette.primaryDark, Palette.primary, Palette.accent],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Metrics
    enum Metric {
        static let corner: CGFloat       = 20
        static let smallCorner: CGFloat  = 12
        static let cardPadding: CGFloat  = 16
        static let avatar: CGFloat       = 52
    }
}

// MARK: - Color hex helper
extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:     Double((hex >> 16) & 0xff) / 255,
            green:   Double((hex >> 08) & 0xff) / 255,
            blue:    Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Classic card (solid white)
struct CardBackground: ViewModifier {
    var fill: Color = Theme.Palette.surface
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.Metric.corner, style: .continuous)
                    .fill(fill)
            )
            .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 5)
    }
}

extension View {
    func card(_ fill: Color = Theme.Palette.surface) -> some View {
        modifier(CardBackground(fill: fill))
    }
}

// MARK: - Glass card (ultra-thin material)
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var borderOpacity: Double = 0.28

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(.white.opacity(borderOpacity), lineWidth: 0.8)
                    }
            }
            .shadow(color: .black.opacity(0.10), radius: 20, y: 8)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Gradient card
struct GradientCard: ViewModifier {
    let gradient: AnyShapeStyle
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(gradient)
            )
            .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }
}

extension View {
    func gradientCard<S: ShapeStyle>(_ gradient: S, cornerRadius: CGFloat = 20) -> some View {
        modifier(GradientCard(gradient: AnyShapeStyle(gradient), cornerRadius: cornerRadius))
    }
}
