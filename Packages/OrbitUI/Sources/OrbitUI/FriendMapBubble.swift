import SwiftUI
import MapKit
import OrbitCore

// MARK: - Direction beam shape (apex at bottom-center, fans upward = north by default)
private struct DirectionalBeam: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))    // apex (bottom center)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY)) // fan left
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY)) // fan right
        p.closeSubpath()
        return p
    }
}

// MARK: - Friend bubble
public struct FriendMapBubble: View {
    public let friend: Friend
    public var isSelected: Bool = false
    public var userCoordinate: Coordinate? = nil

    private var moving: Bool { friend.presence.movement != .stationary && !friend.isGhostMode }
    private var avatarSize: CGFloat { isSelected ? 52 : 42 }
    private var totalSize: CGFloat  { avatarSize + 20 }

    @State private var glowPulse = false

    /// Compass bearing from friend toward user — beam points "you are over there".
    private var bearingToUser: Double? {
        guard let uc = userCoordinate, !friend.isGhostMode else { return nil }
        return friend.coordinate.bearing(to: uc)
    }

    private var batteryColor: Color {
        if friend.presence.isCharging   { return Theme.Palette.mint }
        if friend.presence.isLowBattery { return Theme.Palette.danger }
        return .white.opacity(0.75)
    }

    public init(friend: Friend, isSelected: Bool = false, userCoordinate: Coordinate? = nil) {
        self.friend = friend
        self.isSelected = isSelected
        self.userCoordinate = userCoordinate
    }

    public var body: some View {
        VStack(spacing: 3) {
            ZStack {
                // ── Direction beam (rotated around apex at bottom-center) ──
                if let b = bearingToUser {
                    DirectionalBeam()
                        .fill(
                            LinearGradient(
                                colors: [Theme.Palette.sky.opacity(0.55), .clear],
                                startPoint: .bottom, endPoint: .top
                            )
                        )
                        .frame(width: 34, height: 76)
                        .rotationEffect(.degrees(b), anchor: .bottom)
                        .offset(y: -(avatarSize * 0.45))
                        .allowsHitTesting(false)
                }

                // ── Moving glow ring ──
                if moving {
                    Circle()
                        .fill(ringColor.opacity(glowPulse ? 0.0 : 0.35))
                        .frame(width: avatarSize + 16, height: avatarSize + 16)
                        .animation(
                            .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                            value: glowPulse
                        )
                }

                // ── Avatar ──
                AvatarView(config: friend.avatar,
                           size: avatarSize,
                           showsRing: true,
                           ringColor: ringColor)
                    .shadow(color: ringColor.opacity(isSelected ? 0.55 : 0.28),
                            radius: isSelected ? 12 : 6, y: 2)
                    .scaleEffect(isSelected ? 1.06 : 1.0)
                    .animation(.jelly, value: isSelected)

                // ── Status badges ──
                if friend.presence.isLowBattery && !friend.isGhostMode {
                    badge(color: Theme.Palette.danger, system: "bolt.slash.fill")
                }
                if friend.isGhostMode {
                    badge(color: Color(hex: 0x1C1C1E).opacity(0.9), system: "moon.zzz.fill")
                }
            }
            .frame(width: totalSize, height: totalSize)

            // ── Name tag ──
            Text(friend.displayName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.black.opacity(0.60), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.30), radius: 4, y: 1)

            // ── Battery % ──
            HStack(spacing: 3) {
                Image(systemName: friend.presence.isCharging ? "bolt.fill" : "battery.75")
                    .font(.system(size: 8, weight: .semibold))
                Text("\(friend.presence.batteryLevel)%")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(batteryColor)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.black.opacity(0.50), in: Capsule())
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

// MARK: - Self bubble
public struct SelfMapBubble: View {
    public let avatar: AvatarConfig

    @State private var glow = false

    public init(avatar: AvatarConfig) { self.avatar = avatar }

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
