import SwiftUI

/// 纯代码绘制的卡通头像。根据 `AvatarConfig` 渲染，完全矢量、可任意缩放、无外部素材。
/// 视觉：渐变背景 + 顶部柔光、立体脸、腮红、带高光的眼睛、上扬微笑曲线、分层发型。
struct AvatarView: View {
    let config: AvatarConfig
    var size: CGFloat = 56
    var showsRing: Bool = false
    var ringColor: Color = .white

    private var s: CGFloat { size }
    private var ink: Color { Color(hex: 0x3A3340) }

    var body: some View {
        ZStack {
            config.background.gradient
            RadialGradient(colors: [.white.opacity(0.40), .clear],
                           center: .topLeading, startRadius: s * 0.02, endRadius: s * 0.85)
            face
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(ringColor, lineWidth: showsRing ? s * 0.07 : 0))
        .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.6))
    }

    private var face: some View {
        ZStack {
            // 后置长发
            if config.hair == .long {
                RoundedRectangle(cornerRadius: s * 0.32, style: .continuous)
                    .fill(config.hairColor.color)
                    .frame(width: s * 0.66, height: s * 0.80)
                    .offset(y: s * 0.18)
            }

            // 发色底冠（除光头）
            if config.hair != .bald {
                Circle()
                    .fill(config.hairColor.color)
                    .frame(width: s * 0.64, height: s * 0.64)
                    .offset(y: -s * 0.03)
            }

            // 脸
            Circle()
                .fill(config.skinTone.color)
                .frame(width: s * 0.56, height: s * 0.56)
                .offset(y: s * 0.07)
                .shadow(color: .black.opacity(0.10), radius: s * 0.03, y: s * 0.01)

            // 腮红
            HStack(spacing: s * 0.26) { cheek; cheek }
                .offset(y: s * 0.13)

            // 眼睛
            HStack(spacing: s * 0.13) { eye; eye }
                .offset(y: s * 0.03)

            // 微笑
            Smile()
                .stroke(Color(hex: 0x7A3B2E), style: StrokeStyle(lineWidth: s * 0.035, lineCap: .round))
                .frame(width: s * 0.18, height: s * 0.09)
                .offset(y: s * 0.17)

            // 刘海/发型顶部细节
            fringe

            // 配饰
            accessory
        }
    }

    private var cheek: some View {
        Ellipse()
            .fill(Color(hex: 0xFF8FA3).opacity(0.45))
            .frame(width: s * 0.11, height: s * 0.07)
            .blur(radius: s * 0.006)
    }

    private var eye: some View {
        ZStack {
            Capsule().fill(ink).frame(width: s * 0.066, height: s * 0.095)
            Circle().fill(.white).frame(width: s * 0.026, height: s * 0.026)
                .offset(x: s * 0.012, y: -s * 0.024)
        }
    }

    @ViewBuilder private var fringe: some View {
        switch config.hair {
        case .bald:
            EmptyView()
        case .short, .long:
            // 额前一缕刘海
            Circle()
                .trim(from: 0.52, to: 0.98)
                .fill(config.hairColor.color)
                .frame(width: s * 0.5, height: s * 0.5)
                .rotationEffect(.degrees(180))
                .offset(y: -s * 0.12)
        case .bun:
            ZStack {
                Circle()
                    .trim(from: 0.52, to: 0.98)
                    .fill(config.hairColor.color)
                    .frame(width: s * 0.5, height: s * 0.5)
                    .rotationEffect(.degrees(180))
                    .offset(y: -s * 0.12)
                Circle()
                    .fill(config.hairColor.color)
                    .frame(width: s * 0.2, height: s * 0.2)
                    .offset(y: -s * 0.30)
            }
        }
    }

    @ViewBuilder private var accessory: some View {
        switch config.accessory {
        case .none:
            EmptyView()
        case .glasses:
            HStack(spacing: s * 0.035) {
                Circle().strokeBorder(ink, lineWidth: s * 0.022).frame(width: s * 0.15, height: s * 0.15)
                Circle().strokeBorder(ink, lineWidth: s * 0.022).frame(width: s * 0.15, height: s * 0.15)
            }
            .offset(y: s * 0.03)
        case .cap:
            ZStack {
                // 帽体
                Circle()
                    .trim(from: 0.5, to: 1.0)
                    .fill(Theme.Palette.danger)
                    .frame(width: s * 0.6, height: s * 0.6)
                    .rotationEffect(.degrees(180))
                    .offset(y: -s * 0.15)
                // 帽檐
                Capsule()
                    .fill(Theme.Palette.danger)
                    .frame(width: s * 0.34, height: s * 0.075)
                    .offset(x: s * 0.20, y: -s * 0.13)
                // 帽顶小球
                Circle().fill(.white).frame(width: s * 0.07, height: s * 0.07).offset(y: -s * 0.30)
            }
        }
    }
}

/// 上扬的微笑曲线。
struct Smile: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.midX, y: rect.maxY * 1.7))
        return p
    }
}

#if DEBUG
struct AvatarView_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            AvatarView(config: .default, size: 90)
            AvatarView(config: AvatarConfig(skinTone: .deep, hair: .long, hairColor: .pink, accessory: .cap, background: .pink), size: 90)
            AvatarView(config: AvatarConfig(skinTone: .light, hair: .bun, hairColor: .blonde, accessory: .glasses, background: .sky), size: 90)
        }
        .padding().previewLayout(.sizeThatFits)
    }
}
#endif
