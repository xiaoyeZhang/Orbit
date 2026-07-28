import SwiftUI
import MapKit
import OrbitCore
import OrbitUI
import OrbitServices

struct FriendDetailSheet: View {
    let friendId: String
    var onOpenChat: () -> Void = {}

    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var location: LocationManager
    @Environment(\.dismiss) private var dismiss

    private var friend: Friend? { session.friend(by: friendId) }

    @State private var friendWeatherCode: Int? = nil
    private var friendWeather: WeatherCondition { WeatherCondition(wmoCode: friendWeatherCode ?? -1) }

    var body: some View {
        NavigationStack {
            Group {
                if let friend {
                    content(friend)
                } else {
                    notFoundPlaceholder
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        Haptics.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.Palette.subtle)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - 主内容
    private func content(_ friend: Friend) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroHeader(friend)

                VStack(spacing: 14) {
                    statRow(friend)
                    mapPreview(friend)
                    actionRow(friend)
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        .background(Theme.Palette.groupedBackground.ignoresSafeArea())
        .onAppear { loadFriendWeather() }
    }

    // MARK: - 渐变英雄头部
    private func heroHeader(_ friend: Friend) -> some View {
        ZStack(alignment: .bottom) {
            // 渐变背景
            LinearGradient(
                colors: [heroColor(friend).opacity(0.85), heroColor(friend).opacity(0.45), .clear],
                startPoint: .topLeading, endPoint: .bottom
            )
            .frame(height: 220)
            .overlay(alignment: .topLeading) {
                // 装饰圆
                Circle().fill(.white.opacity(0.07)).frame(width: 160).offset(x: 110, y: -50)
                Circle().fill(.white.opacity(0.05)).frame(width: 100).offset(x: -20, y: 30)
            }
            .background(heroColor(friend).opacity(0.92).ignoresSafeArea(edges: .top))

            // 头像 + 名字叠在底部，向下偏移使其跨越卡片边界
            VStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(config: friend.avatar, size: 90,
                               showsRing: true, ringColor: .white)
                        .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
                        .breathing(scale: 1.025, duration: 3.2)

                    // 在线点
                    if !friend.isGhostMode {
                        OnlineDot(size: 14)
                            .offset(x: 2, y: 2)
                    }
                }

                VStack(spacing: 5) {
                    Text(friend.displayName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 5) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 13))
                        Text(friend.isGhostMode ? "对方已开启隐身" : friend.locationName)
                            .lineLimit(1)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))

                    if !friend.isGhostMode {
                        HStack(spacing: 5) {
                            Image(systemName: friend.coordinate.localTimeOfDay.systemImage)
                                .font(.system(size: 12))
                            Text("对方 \(friend.coordinate.localTimeOfDay.title) · \(friendWeather.title) · \(friend.coordinate.localHour)时")
                                .lineLimit(1)
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.70))
                    }

                    Text("更新于 \(friend.lastUpdated.relativeShort)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.60))
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - 状态三格
    private func statRow(_ friend: Friend) -> some View {
        HStack(spacing: 10) {
            statTile(
                gradient: Theme.oceanGradient,
                icon: "location.fill",
                value: friend.distance(from: location.userCoordinate ?? location.fallbackCoordinate),
                label: "距你")

            statTile(
                gradient: Theme.brandGradient,
                icon: friend.presence.movement.systemImage,
                value: friend.presence.movement.title,
                label: friend.presence.speedKmh > 0 ? "\(Int(friend.presence.speedKmh)) km/h" : "当前状态")

            statTile(
                gradient: batteryGradient(friend.presence),
                icon: friend.presence.isCharging ? "bolt.fill" : batteryIcon(friend.presence.batteryLevel),
                value: "\(friend.presence.batteryLevel)%",
                label: friend.presence.isCharging ? "充电中" : "电量")
        }
    }

    private func statTile<G: ShapeStyle>(gradient: G, icon: String, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(AnyShapeStyle(gradient))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(value).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.Palette.ink)
            Text(label).font(.caption2).foregroundStyle(Theme.Palette.subtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .card()
    }

    // MARK: - 小地图
    private func mapPreview(_ friend: Friend) -> some View {
        ZStack(alignment: .bottomLeading) {
            Map(coordinateRegion: .constant(MKCoordinateRegion(
                center: friend.coordinate.clLocationCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.009, longitudeDelta: 0.009))),
                annotationItems: [friend]) { f in
                MapAnnotation(coordinate: f.coordinate.clLocationCoordinate) {
                    FriendMapBubble(friend: f)
                }
            }
            .frame(height: 170)
            .allowsHitTesting(false)

            // 左下角地名标签
            if !friend.isGhostMode {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(heroColor(friend))
                    Text(friend.locationName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ink)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }

    // MARK: - 操作按钮
    private func actionRow(_ friend: Friend) -> some View {
        HStack(spacing: 10) {
            NavigationLink {
                ChatView(conversation: session.ensureConversation(for: friend))
            } label: {
                actionChip(icon: "bubble.left.fill", label: "聊天",
                           gradient: AnyShapeStyle(Theme.brandGradient))
            }
            .buttonStyle(.pressable(scale: 0.95))

            Button {
                Task { await pingFriend(friend) }
            } label: {
                actionChip(icon: "hand.wave.fill", label: "戳一下",
                           gradient: AnyShapeStyle(Theme.sunsetGradient))
            }
            .buttonStyle(.pressable(scale: 0.95))

            Button {
                Task { await session.toggleFavorite(friend) }
            } label: {
                actionChip(icon: friend.isFavorite ? "star.fill" : "star",
                           label: friend.isFavorite ? "已关注" : "关注",
                           gradient: favoriteGradient(friend.isFavorite))
            }
            .buttonStyle(.pressable(scale: 0.95))
        }
    }

    private func actionChip<G: ShapeStyle>(icon: String, label: String, gradient: G) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
            Text(label)
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AnyShapeStyle(gradient))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        )
    }

    private func favoriteGradient(_ isFav: Bool) -> AnyShapeStyle {
        isFav ? AnyShapeStyle(Theme.sunsetGradient) : AnyShapeStyle(Theme.Palette.subtle.opacity(0.55))
    }

    private func batteryGradient(_ presence: PresenceState) -> AnyShapeStyle {
        if presence.isCharging { return AnyShapeStyle(Theme.oceanGradient) }
        if presence.isLowBattery {
            return AnyShapeStyle(LinearGradient(
                colors: [Theme.Palette.danger, Theme.Palette.sunshine],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(Theme.skyGradient)
    }

    // MARK: - 辅助
    private func heroColor(_ friend: Friend) -> Color {
        switch friend.presence.movement {
        case .stationary: return Theme.Palette.primary
        case .walking:    return Theme.Palette.mint
        case .driving:    return Theme.Palette.sky
        case .flying:     return Theme.Palette.accent
        }
    }

    private func batteryIcon(_ level: Int) -> String {
        switch level {
        case 0..<15: return "battery.0"
        case 15..<40: return "battery.25"
        case 40..<70: return "battery.50"
        case 70..<90: return "battery.75"
        default:      return "battery.100"
        }
    }

    private func pingFriend(_ friend: Friend) async {
        Haptics.medium()
        let convo = session.ensureConversation(for: friend)
        _ = try? await session.backend.sendMessage(.ping, to: convo.id)
    }

    private func loadFriendWeather() {
        guard let friend else { return }
        Task {
            let code = await fetchWeatherCode(for: friend.coordinate)
            await MainActor.run { friendWeatherCode = code }
        }
    }

    // MARK: - 占位
    private var notFoundPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.slash")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.Palette.subtle)
            Text("好友不存在或已被移除")
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.subtle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// 让渐变可以跨类型传递
private typealias AnyGradient = AnyShapeStyle
