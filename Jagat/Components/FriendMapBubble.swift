import SwiftUI

/// 地图上的好友气泡：头像 + 名牌，移动时带光晕，常态轻呼吸，选中 Q 弹放大。
struct FriendMapBubble: View {
    let friend: Friend
    var isSelected: Bool = false

    private var moving: Bool { friend.presence.movement != .stationary && !friend.isGhostMode }
    private var avatarSize: CGFloat { isSelected ? 52 : 42 }
    private var totalSize: CGFloat { avatarSize + 20 }   // 固定 frame，避免 scaleEffect 扩张 annotation 容器

    @State private var glowPulse = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // 移动中：opacity 脉冲光晕（不用 scaleEffect，避免 MapAnnotation 容器膨胀）
                if moving {
                    Circle()
                        .fill(ringColor.opacity(glowPulse ? 0.0 : 0.35))
                        .frame(width: avatarSize + 16, height: avatarSize + 16)
                        .animation(
                            .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                            value: glowPulse
                        )
                }

                AvatarView(config: friend.avatar,
                           size: avatarSize,
                           showsRing: true,
                           ringColor: ringColor)
                    .shadow(color: ringColor.opacity(isSelected ? 0.5 : 0.25),
                            radius: isSelected ? 10 : 5, y: 2)
                    .scaleEffect(isSelected ? 1.06 : 1.0)
                    .animation(.jelly, value: isSelected)

                // 低电量红点
                if friend.presence.isLowBattery {
                    badge(color: Theme.Palette.danger, system: "bolt.slash.fill")
                }
                // 隐身
                if friend.isGhostMode {
                    badge(color: Theme.Palette.ink.opacity(0.8), system: "moon.zzz.fill")
                }
            }
            .frame(width: totalSize, height: totalSize)  // 固定容器大小

            Text(friend.displayName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.Palette.ink)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
        }
        .onAppear { glowPulse = true }
    }

    private func badge(color: Color, system: String) -> some View {
        Image(systemName: system)
            .font(.system(size: avatarSize * 0.2, weight: .bold))
            .foregroundStyle(.white)
            .padding(avatarSize * 0.08)
            .background(Circle().fill(color))
            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
            .offset(x: avatarSize * 0.34, y: -avatarSize * 0.34)
    }

    private var ringColor: Color {
        switch friend.presence.movement {
        case .stationary: return .white
        case .walking:    return Theme.Palette.mint
        case .driving:    return Theme.Palette.sky
        case .flying:     return Theme.Palette.primary
        }
    }
}

/// 自己在地图上的位置气泡：固定大小，避免 scaleEffect 动画撑大 MapAnnotation 容器。
struct SelfMapBubble: View {
    let avatar: AvatarConfig

    @State private var glow = false

    var body: some View {
        ZStack {
            // 柔和光晕：用 opacity 动画，不用 scaleEffect
            Circle()
                .fill(Theme.Palette.sky.opacity(glow ? 0.0 : 0.30))
                .frame(width: 64, height: 64)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glow)

            // 白色描边环
            Circle()
                .strokeBorder(.white, lineWidth: 3)
                .frame(width: 54, height: 54)

            AvatarView(config: avatar, size: 42, showsRing: false)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 2)

            // 天蓝内描边
            Circle()
                .strokeBorder(Theme.Palette.sky, lineWidth: 2)
                .frame(width: 42, height: 42)
        }
        .frame(width: 64, height: 64)  // 固定 frame，MapAnnotation 容器不会超过此尺寸
        .onAppear { glow = true }
    }
}
