import SwiftUI
import MapKit
import OrbitCore

// MARK: - Direction beam (apex at bottom-center, fans upward = north)
private struct DirectionalBeam: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Friend bubble (solid color circle + name, reference-style)
public struct FriendMapBubble: View {
    public let friend: Friend
    public var isSelected: Bool = false
    public var userCoordinate: Coordinate? = nil
    // 异地氛围：好友所在地的当地时间（图标/文案/色调），由调用方算好后传入
    public var localTimeIcon: String? = nil
    public var localTimeLabel: String? = nil
    public var localTimeTint: Color? = nil

    private var moving: Bool { friend.presence.movement != .stationary && !friend.isGhostMode }
    private var bubbleSize: CGFloat { isSelected ? 58 : 48 }

    @State private var glowPulse = false

    private var bearingToUser: Double? {
        guard let uc = userCoordinate, !friend.isGhostMode else { return nil }
        return friend.coordinate.bearing(to: uc)
    }

    private var bubbleColor: Color {
        // Derive color from avatar hue or use sky as default
        switch (friend.id.hashValue % 5 + 5) % 5 {
        case 0: return Theme.Palette.sky
        case 1: return Theme.Palette.primary
        case 2: return Theme.Palette.mint
        case 3: return Color(hex: 0xFF9F43)
        default: return Color(hex: 0xEE5A24)
        }
    }

    private var batteryFraction: Double {
        Double(friend.presence.batteryLevel) / 100.0
    }

    public init(friend: Friend, isSelected: Bool = false, userCoordinate: Coordinate? = nil,
                localTimeIcon: String? = nil, localTimeLabel: String? = nil, localTimeTint: Color? = nil) {
        self.friend = friend
        self.isSelected = isSelected
        self.userCoordinate = userCoordinate
        self.localTimeIcon = localTimeIcon
        self.localTimeLabel = localTimeLabel
        self.localTimeTint = localTimeTint
    }

    public var body: some View {
        VStack(spacing: 0) {
            // ── 异地氛围：好友所在地当地时间 ──
            if let icon = localTimeIcon, let label = localTimeLabel, let tint = localTimeTint {
                HStack(spacing: 3) {
                    Image(systemName: icon)
                        .font(.system(size: 9))
                    Text(label)
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(tint.opacity(0.9), in: Capsule())
                .shadow(color: tint.opacity(0.5), radius: 4, y: 2)
                .padding(.bottom, 4)
            }

            // ── "在线" badge ──
            if !friend.isGhostMode {
                Text("在线")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Theme.Palette.online, in: Capsule())
                    .shadow(color: Theme.Palette.online.opacity(0.5), radius: 4, y: 2)
                    .padding(.bottom, 4)
            }

            // ── Main bubble ──
            ZStack {
                // Direction beam behind bubble
                if let b = bearingToUser {
                    DirectionalBeam()
                        .fill(
                            LinearGradient(
                                colors: [Theme.Palette.sky.opacity(0.60), .clear],
                                startPoint: .bottom, endPoint: .top
                            )
                        )
                        .frame(width: 36, height: 80)
                        .rotationEffect(.degrees(b), anchor: .bottom)
                        .offset(y: -(bubbleSize * 0.42))
                        .allowsHitTesting(false)
                }

                // Moving glow
                if moving {
                    Circle()
                        .fill(bubbleColor.opacity(glowPulse ? 0 : 0.3))
                        .frame(width: bubbleSize + 18, height: bubbleSize + 18)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                                   value: glowPulse)
                }

                // Main circle
                Circle()
                    .fill(bubbleColor)
                    .frame(width: bubbleSize, height: bubbleSize)
                    .shadow(color: bubbleColor.opacity(isSelected ? 0.6 : 0.3),
                            radius: isSelected ? 14 : 8, y: 3)
                    .scaleEffect(isSelected ? 1.08 : 1.0)
                    .animation(.jelly, value: isSelected)

                // Name inside circle
                Text(friend.displayName)
                    .font(.system(size: bubbleSize * 0.28, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: bubbleSize * 0.75)
                    .scaleEffect(isSelected ? 1.08 : 1.0)
                    .animation(.jelly, value: isSelected)

                // Ghost mode overlay
                if friend.isGhostMode {
                    Circle()
                        .fill(Color(hex: 0x1C1C1E).opacity(0.75))
                        .frame(width: bubbleSize, height: bubbleSize)
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: bubbleSize * 0.3))
                        .foregroundStyle(.white.opacity(0.7))
                }

                // Low battery badge
                if friend.presence.isLowBattery && !friend.isGhostMode {
                    Image(systemName: "bolt.slash.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Circle().fill(Theme.Palette.danger))
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1))
                        .offset(x: bubbleSize * 0.38, y: -bubbleSize * 0.38)
                }
            }
            .frame(width: bubbleSize + 20, height: bubbleSize + 20)

            // ── "此刻 | battery bar | %" ──
            HStack(spacing: 5) {
                Text(lastSeenLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))

                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 0.5, height: 9)

                // Battery bar
                GeometryReader { _ in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white.opacity(0.2))
                            .frame(width: 22, height: 8)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(batteryBarColor)
                            .frame(width: 22 * batteryFraction, height: 8)
                    }
                }
                .frame(width: 22, height: 8)

                Text("\(friend.presence.batteryLevel)%")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.black.opacity(0.55), in: Capsule())
            .padding(.top, 4)
        }
        .onAppear { glowPulse = true }
    }

    private var batteryBarColor: Color {
        if friend.presence.isCharging { return Theme.Palette.mint }
        if friend.presence.isLowBattery { return Theme.Palette.danger }
        return Theme.Palette.online
    }

    private var lastSeenLabel: String {
        let s = Date().timeIntervalSince(friend.lastUpdated)
        if s < 60 { return "此刻" }
        if s < 3600 { return "\(Int(s/60))分钟" }
        return "\(Int(s/3600))小时"
    }
}

// MARK: - Self bubble
public struct SelfMapBubble: View {
    public let avatar: AvatarConfig
    public var isGhostMode: Bool = false

    @State private var glow = false

    public init(avatar: AvatarConfig, isGhostMode: Bool = false) {
        self.avatar = avatar
        self.isGhostMode = isGhostMode
    }

    private var accent: Color { isGhostMode ? Color(hex: 0x8E8E93) : Theme.Palette.sky }

    public var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(glow ? 0.0 : 0.30))
                .frame(width: 64, height: 64)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glow)

            Circle()
                .strokeBorder(isGhostMode ? Color(hex: 0x8E8E93) : .white, lineWidth: 3)
                .frame(width: 54, height: 54)

            AvatarView(config: avatar, size: 42, showsRing: false)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 2)

            // 隐身遮罩
            if isGhostMode {
                Circle()
                    .fill(Color(hex: 0x1C1C1E).opacity(0.55))
                    .frame(width: 54, height: 54)
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Circle()
                .strokeBorder(accent, lineWidth: 2)
                .frame(width: 42, height: 42)
        }
        .frame(width: 64, height: 64)
        .onAppear { glow = true }
    }
}
