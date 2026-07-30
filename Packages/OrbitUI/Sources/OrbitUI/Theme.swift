import SwiftUI

// MARK: - Design System

public enum Theme {

    // MARK: Palette (颜色规范)
    public enum Palette {
        // Brand
        public static let primary      = Color(hex: 0x6C5CE7)
        public static let primaryDark  = Color(hex: 0x4834D4)
        public static let accent       = Color(hex: 0xFD79A8)
        public static let sunshine     = Color(hex: 0xFDCB6E)
        public static let gold         = Color(hex: 0xFFC312)
        public static let mint         = Color(hex: 0x00D2A8)
        public static let sky          = Color(hex: 0x54A0FF)
        public static let danger       = Color(hex: 0xFF6B6B)
        public static let online       = Color(hex: 0x2ECC71)

        // Semantic — light mode fallbacks (currently only used in dark mode)
        public static let ink          = Color(.label)
        public static let subtle       = Color(.secondaryLabel)
        public static let surface      = Color(.systemBackground)
        public static let groupedBackground = Color(.systemGroupedBackground)

        // Dark-first palette (主用)
        public static let bg           = Color(hex: 0x0D0D0D)
        public static let card         = Color(hex: 0x1C1C1E)
        public static let card2        = Color(hex: 0x2C2C2E)
        public static let separator    = Color(white: 1.0, opacity: 0.08)
        public static let textPrimary  = Color.white
        public static let textSecondary = Color(white: 1.0, opacity: 0.50)

        // Accent variants (formerly hardcoded in views)
        public static let tangerine    = Color(hex: 0xFF9F43)
        public static let indigo       = Color(hex: 0x5352ED)
        public static let pinkRed      = Color(hex: 0xFF6B81)
        public static let emerald      = Color(hex: 0x2BCB96)

        // Surfaces for overlays
        public static let darkInk      = Color(hex: 0x1A1A1A)
        public static let memberGradientStart = Color(hex: 0x2D2D44)
        public static let memberGradientEnd   = Color(hex: 0x1A1A2E)
    }

    // MARK: Typography (字体规范)
    /// 使用 `Theme.Typography.xxx` 替代全局 `.system(size:weight:)` 硬编码。
    /// 带参数版本用于需要定制 weight / design 的场景（如 statPill 的 .rounded）。
    public enum Typography {
        /// 34pt — 地图城市名
        public static func titleLarge(_ weight: Font.Weight = .heavy, design: Font.Design = .default) -> Font {
            .system(size: 34, weight: weight, design: design)
        }
        /// 22pt — 表单标题、统计数字
        public static func title(_ weight: Font.Weight = .bold, design: Font.Design = .default) -> Font {
            .system(size: 22, weight: weight, design: design)
        }
        /// 20pt — 次级标题、详情页标题
        public static func title3(_ weight: Font.Weight = .bold, design: Font.Design = .default) -> Font {
            .system(size: 20, weight: weight, design: design)
        }
        /// 17–18pt — 段落标题（section header、会员标题）
        public static func headline(_ weight: Font.Weight = .semibold, design: Font.Design = .default) -> Font {
            .system(size: 17, weight: weight, design: design)
        }
        /// 15pt — 正文 / 列表行标题 / 聊天文字
        public static func body(_ weight: Font.Weight = .medium, design: Font.Design = .default) -> Font {
            .system(size: 15, weight: weight, design: design)
        }
        /// 14pt — 辅助文字
        public static func callout(_ weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
            .system(size: 14, weight: weight, design: design)
        }
        /// 13pt — 小标签 / 描述 / 输入框
        public static func subheadline(_ weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
            .system(size: 13, weight: weight, design: design)
        }
        /// 12pt — 说明文字 / 日期 / 按钮小字
        public static func caption(_ weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
            .system(size: 12, weight: weight, design: design)
        }
        /// 11pt — 角标 / 微标
        public static func caption2(_ weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
            .system(size: 11, weight: weight, design: design)
        }
        /// 9pt — 超小角标
        public static func micro(_ weight: Font.Weight = .heavy, design: Font.Design = .default) -> Font {
            .system(size: 9, weight: weight, design: design)
        }

        // MARK: Display (大号展示字体)
        /// 28pt — 统计大数 / emoji 展示 / 城市名
        public static func title2(_ weight: Font.Weight = .heavy, design: Font.Design = .default) -> Font {
            .system(size: 28, weight: weight, design: design)
        }
        /// 44pt — 空态大 emoji / 距离展示
        public static func display(_ weight: Font.Weight = .light, design: Font.Design = .default) -> Font {
            .system(size: 44, weight: weight, design: design)
        }
        /// 72pt — 天气温度等超大展示
        public static func displayLarge(_ weight: Font.Weight = .thin, design: Font.Design = .default) -> Font {
            .system(size: 72, weight: weight, design: design)
        }

        // MARK: Convenience — 最常用默认
        public static let titleLargeDefault: Font = titleLarge()
        public static let title2Default:      Font = title2()
        public static let titleDefault:       Font = title()
        public static let title3Default:      Font = title3()
        public static let headlineDefault:    Font = headline()
        public static let bodyDefault:        Font = body()
        public static let calloutDefault:     Font = callout()
        public static let subheadlineDefault: Font = subheadline()
        public static let captionDefault:     Font = caption()
        public static let caption2Default:    Font = caption2()
        public static let displayDefault:     Font = display()
        public static let displayLargeDefault: Font = displayLarge()

        // SF Symbol 专用小号
        public static func symbol(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
            .system(size: size, weight: weight)
        }
    }

    // MARK: Spacing (间距规范)
    public enum Spacing {
        public static let xs: CGFloat  = 4
        public static let sm: CGFloat  = 8
        public static let md: CGFloat  = 12
        public static let lg: CGFloat  = 16
        public static let xl: CGFloat  = 20
        public static let xxl: CGFloat = 32

        // 复用快捷
        public static let listRowV: CGFloat     = 13     // 列表行纵向内边距
        public static let listDividerLeading: CGFloat = 74   // 分隔线左侧留白（图标 44 + 间距 14 + 半 16）
    }

    // MARK: Corner (圆角规范)
    public enum Radius {
        public static let sm: CGFloat  = 8
        public static let md: CGFloat  = 12
        public static let lg: CGFloat  = 16
        public static let xl: CGFloat  = 20
        public static let pill: CGFloat = 999
    }

    // MARK: Gradients
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
    /// 会员卡专用渐变
    public static var memberGradient: LinearGradient {
        LinearGradient(colors: [Palette.memberGradientStart, Palette.memberGradientEnd],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Legacy Metric (kept for compat, prefer Spacing & Radius)
    public enum Metric {
        public static let corner: CGFloat      = Radius.xl
        public static let smallCorner: CGFloat = Radius.md
        public static let cardPadding: CGFloat = Spacing.lg
        public static let avatar: CGFloat      = 52
    }
}

// MARK: - Color Helper

public extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red:     Double((hex >> 16) & 0xff) / 255,
                  green:   Double((hex >> 08) & 0xff) / 255,
                  blue:    Double((hex >> 00) & 0xff) / 255,
                  opacity: alpha)
    }
}

// MARK: - Shadow Modifiers (阴影规范)

public enum ThemeShadow {
    /// 卡片阴影 — 轻微浮起
    case card
    /// 提升阴影 — 弹窗 / sheet 内容
    case elevated
    /// 悬浮阴影 — 地图上的浮动按钮
    case floating
    /// 辉光 — 品牌色发光（用于品牌按钮）
    case glow(Color)

    fileprivate var color: Color {
        switch self {
        case .card:     return .black.opacity(0.06)
        case .elevated: return .black.opacity(0.12)
        case .floating: return .black.opacity(0.35)
        case .glow:     return .clear // handled in modifier
        }
    }
    fileprivate var radius: CGFloat {
        switch self {
        case .card: 12; case .elevated: 16; case .floating: 8; case .glow: 10
        }
    }
    fileprivate var y: CGFloat {
        switch self {
        case .card: 4; case .elevated: 6; case .floating: 3; case .glow: 4
        }
    }
}

public extension View {
    /// 应用统一阴影
    func themedShadow(_ shadow: ThemeShadow) -> some View {
        switch shadow {
        case .glow(let c):
            return self.shadow(color: c.opacity(0.4), radius: shadow.radius, y: shadow.y)
        default:
            return self.shadow(color: shadow.color, radius: shadow.radius, y: shadow.y)
        }
    }

    // Convenience shortcuts
    func shadowCard()     -> some View { themedShadow(.card) }
    func shadowElevated() -> some View { themedShadow(.elevated) }
    func shadowFloating() -> some View { themedShadow(.floating) }
}

// MARK: - Card Modifiers

public struct CardBackground: ViewModifier {
    var fill: Color
    public init(fill: Color = Theme.Palette.surface) { self.fill = fill }
    public func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous).fill(fill))
            .shadowCard()
    }
}

public extension View {
    func card(_ fill: Color = Theme.Palette.surface) -> some View {
        modifier(CardBackground(fill: fill))
    }
    func darkCard() -> some View {
        modifier(CardBackground(fill: Theme.Palette.card))
    }
    func glassCard(cornerRadius: CGFloat = Theme.Radius.xl) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
    func gradientCard<S: ShapeStyle>(_ gradient: S, cornerRadius: CGFloat = Theme.Radius.xl) -> some View {
        modifier(GradientCard(gradient: AnyShapeStyle(gradient), cornerRadius: cornerRadius))
    }
}

public struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat
    public init(cornerRadius: CGFloat = Theme.Radius.xl) { self.cornerRadius = cornerRadius }
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
            .shadowElevated()
    }
}

public struct GradientCard: ViewModifier {
    let gradient: AnyShapeStyle
    var cornerRadius: CGFloat
    public init(gradient: AnyShapeStyle, cornerRadius: CGFloat = Theme.Radius.xl) {
        self.gradient = gradient; self.cornerRadius = cornerRadius
    }
    public func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(gradient))
            .shadowElevated()
    }
}

// MARK: - Components Library (通用组件)

/// 设置列表行 — 图标 + 标题 + 副标题 + 尾标 + chevron
/// 用于 ProfileView / 各类设置列表
public struct SettingsRow<Leading: View, Trailing: View>: View {
    let leading: Leading
    let title: String
    let subtitle: String?
    let trailing: Trailing
    let showChevron: Bool
    let action: (() -> Void)?

    public init(
        @ViewBuilder leading: () -> Leading,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        showChevron: Bool = true,
        action: (() -> Void)? = nil
    ) {
        self.leading = leading()
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
        self.showChevron = showChevron
        self.action = action
    }

    public var body: some View {
        Group {
            if let action {
                Button(action: action) { rowContent.contentShape(Rectangle()) }
                    .buttonStyle(.pressable(scale: 0.94))
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: Theme.Spacing.md) {
            leading
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Palette.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.caption2())
                        .foregroundStyle(Theme.Palette.subtle)
                }
            }
            Spacer()
            trailing
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.Palette.subtle)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.listRowV)
    }
}

/// 便捷：仅图标 + 标题 的设置行（最常用）
public extension SettingsRow where Leading == SettingsIcon, Trailing == EmptyView {
    init(
        icon: String,
        gradient: AnyShapeStyle,
        title: String,
        subtitle: String? = nil,
        showChevron: Bool = true,
        action: (() -> Void)? = nil
    ) {
        self.init(
            leading: { SettingsIcon(systemName: icon, gradient: gradient) },
            title: title, subtitle: subtitle,
            trailing: { EmptyView() },
            showChevron: showChevron, action: action
        )
    }
}

/// 设置行图标（小圆角方块 + SF Symbol）
public struct SettingsIcon: View {
    let systemName: String
    let gradient: AnyShapeStyle

    public init(systemName: String, gradient: AnyShapeStyle) {
        self.systemName = systemName
        self.gradient = gradient
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(gradient)
                .frame(width: 30, height: 30)
            Image(systemName: systemName)
                .font(Theme.Typography.symbol(13, .bold))
                .foregroundStyle(.white)
        }
    }
}

/// 胶囊徽章 — 用于「已开通」「隐身中」「解锁10+权益」等标签
public struct BadgeChip: View {
    let text: String
    let textColor: Color
    let bgColor: Color

    public init(text: String, textColor: Color, bgColor: Color) {
        self.text = text; self.textColor = textColor; self.bgColor = bgColor
    }

    public var body: some View {
        Text(text)
            .font(Theme.Typography.caption2(.semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(bgColor, in: Capsule())
    }
}

/// 空态占位 — 图标 + 标题 + 描述 + 可选 CTA 按钮
public struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionLabel: String?
    let action: (() -> Void)?
    var tint: Color = Theme.Palette.primary

    public init(
        icon: String, title: String, subtitle: String,
        actionLabel: String? = nil, action: (() -> Void)? = nil,
        tint: Color = Theme.Palette.primary
    ) {
        self.icon = icon; self.title = title; self.subtitle = subtitle
        self.actionLabel = actionLabel; self.action = action
        self.tint = tint
    }

    public var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 84, height: 84)
                Circle()
                    .fill(Theme.Palette.card2)
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(Theme.Typography.symbol(30, .semibold))
                    .foregroundStyle(tint)
            }

            VStack(spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.Typography.headline(.semibold))
                    .foregroundStyle(Theme.Palette.ink)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(Theme.Typography.subheadline())
                    .foregroundStyle(Theme.Palette.subtle)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            if let actionLabel, let action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(Theme.Typography.callout(.bold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.vertical, Theme.Spacing.sm + 1)
                        .background(Theme.Palette.primary, in: Capsule())
                }
                .buttonStyle(.pressable(scale: 0.94))
            }
        }
    }
}

/// 分隔线 — 统一左侧留白
public struct ListDivider: View {
    let leadingPadding: CGFloat
    public init(leadingPadding: CGFloat = Theme.Spacing.listDividerLeading) {
        self.leadingPadding = leadingPadding
    }
    public var body: some View {
        Divider().padding(.leading, leadingPadding)
    }
}
