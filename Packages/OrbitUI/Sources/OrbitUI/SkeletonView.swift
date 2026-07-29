import SwiftUI

// MARK: - Skeleton ViewModifier

/// 骨架屏修饰器 — 加载态占位 + 光泽扫过动画
public struct SkeletonModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    var shape: SkeletonShape
    var baseColor: Color

    public enum SkeletonShape {
        case roundedRect  // 默认圆角矩形（自动匹配容器）
        case circle       // 圆形（头像/图标）
        case line(height: CGFloat) // 横线（文字行模拟）
    }

    public init(shape: SkeletonShape = .roundedRect, baseColor: Color = Theme.Palette.card2) {
        self.shape = shape
        self.baseColor = baseColor
    }

    public func body(content: Content) -> some View {
        content
            .opacity(0) // 隐藏原内容，只显示占位
            .overlay(GeometryReader { geo in
                skeletonOverlay(size: geo.size)
            })
            .onAppear {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }

    @ViewBuilder
    private func skeletonOverlay(size: CGSize) -> some View {
        switch shape {
        case .roundedRect:
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .fill(baseColor)
                .frame(width: size.width, height: size.height)
                .shimmerMask(phase: phase, size: size)

        case .circle:
            Circle()
                .fill(baseColor)
                .frame(width: size.width, height: size.height)
                .shimmerMask(phase: phase, size: size, isCircle: true)

        case .line(let height):
            RoundedRectangle(cornerRadius: 4)
                .fill(baseColor)
                .frame(width: size.width, height: height)
                .shimmerMask(phase: phase, size: CGSize(width: size.width, height: height))
        }
    }
}

// MARK: - Shimmer Mask

private extension View {
    func shimmerMask(phase: CGFloat, size: CGSize, isCircle: Bool = false) -> some View {
        self.mask(
            isCircle
                ? AnyView(
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .white.opacity(0.10), location: 0.35),
                                    .init(color: .white.opacity(0.18), location: 0.50),
                                    .init(color: .white.opacity(0.10), location: 0.65),
                                    .init(color: .clear, location: 1),
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .rotationEffect(.degrees(30))
                        .offset(x: phase * max(size.width, size.height) * 2)
                )
                : AnyView(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .white.opacity(0.10), location: 0.35),
                                    .init(color: .white.opacity(0.18), location: 0.50),
                                    .init(color: .white.opacity(0.10), location: 0.65),
                                    .init(color: .clear, location: 1),
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .rotationEffect(.degrees(30))
                        .offset(x: phase * max(size.width, size.height) * 2)
                )
        )
    }
}

// MARK: - Convenience Modifiers

public extension View {
    /// 骨架屏占位 — 默认圆角矩形
    func skeleton(baseColor: Color = Theme.Palette.card2) -> some View {
        modifier(SkeletonModifier(shape: .roundedRect, baseColor: baseColor))
    }

    /// 骨架屏 — 圆形（头像/图标）
    func skeletonCircle(baseColor: Color = Theme.Palette.card2) -> some View {
        modifier(SkeletonModifier(shape: .circle, baseColor: baseColor))
    }

    /// 骨架屏 — 文字行模拟
    func skeletonLine(height: CGFloat = 12, baseColor: Color = Theme.Palette.card2) -> some View {
        modifier(SkeletonModifier(shape: .line(height: height), baseColor: baseColor))
    }
}

// MARK: - Skeleton Wrapper View（无原内容的纯占位）

/// 纯占位骨架视图 — 不需要实际内容，直接展示骨架形状
public struct SkeletonBlock: View {
    var width: CGFloat?
    var height: CGFloat
    var shape: SkeletonModifier.SkeletonShape
    var baseColor: Color

    @State private var phase: CGFloat = -1

    public init(
        width: CGFloat? = nil,
        height: CGFloat = 12,
        shape: SkeletonModifier.SkeletonShape = .roundedRect,
        baseColor: Color = Theme.Palette.card2
    ) {
        self.width = width
        self.height = height
        self.shape = shape
        self.baseColor = baseColor
    }

    private var isCircleShape: Bool {
        if case .circle = shape { return true }
        return false
    }

    public var body: some View {
        Group {
            switch shape {
            case .roundedRect:
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(baseColor)
                    .frame(width: width, height: height)

            case .circle:
                Circle()
                    .fill(baseColor)
                    .frame(width: height, height: height)

            case .line:
                RoundedRectangle(cornerRadius: 4)
                    .fill(baseColor)
                    .frame(width: width ?? height * 8, height: height)
            }
        }
        .shimmerMask(phase: phase, size: CGSize(width: width ?? 100, height: height),
                     isCircle: isCircleShape)
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}