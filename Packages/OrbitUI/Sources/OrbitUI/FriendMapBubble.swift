import SwiftUI
import MapKit
import OrbitCore

/// 地图上的好友气泡：头像 + 名牌，移动时带光晕，常态轻呼吸，选中 Q 弹放大。
public struct FriendMapBubble: View {
    public let friend: Friend
    public var isSelected: Bool = false

    private var moving: Bool { friend.presence.movement != .stationary && !friend.isGhostMode }
    private var avatarSize: CGFloat { isSelected ? 52 : 42 }
    private var totalSize: CGFloat { avatarSize + 20 }

    @State private var glowPulse = false

    public init(friend: Friend, isSelected: Bool = false) {
        self.friend = friend
        self.isSelected = isSelected
    }

    public var body: some View {
        VStack(spacing: 4) {
            ZStack {
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

                if friend.presence.isLowBattery {
                    badge(color: Theme.Palette.danger, system: "bolt.slash.fill")
                }
                if friend.isGhostMode {
                    badge(color: Theme.Palette.ink.opacity(0.8), system: "moon.zzz.fill")
                }
            }
            .frame(width: totalSize, height: totalSize)

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

/// 自己在地图上的位置气泡。
public struct SelfMapBubble: View {
    public let avatar: AvatarConfig

    @State private var glow = false

    public init(avatar: AvatarConfig) {
        self.avatar = avatar
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(Theme.Palette.sky.opacity(glow ? 0.0 : 0.30))
                .frame(width: 64, height: 64)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glow)

            Circle()
                .strokeBorder(.white, lineWidth: 3)
                .frame(width: 54, height: 54)

            AvatarView(config: avatar, size: 42, showsRing: false)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 2)

            Circle()
                .strokeBorder(Theme.Palette.sky, lineWidth: 2)
                .frame(width: 42, height: 42)
        }
        .frame(width: 64, height: 64)
        .onAppear { glow = true }
    }
}
