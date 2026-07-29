import SwiftUI
import MapKit
import CoreLocation
import OrbitCore
import OrbitUI
import OrbitServices

// MARK: - Layout Constants (经验偏移：自定义浮动 TabBar 高度 + 底部安全区)
private enum MapLayout {
    /// 幽灵模式横幅底部偏移
    static let ghostBannerBottom: CGFloat = 72
    /// 底部功能胶囊偏移
    static let bottomPillBottom: CGFloat = 120
    /// 邀请贴纸底部偏移
    static let inviteStickerBottom: CGFloat = 136
}

private enum MapEntity: Identifiable {
    case me(Coordinate, AvatarConfig, Bool)   // Bool = 自己是否隐身
    case friend(Friend)

    var id: String {
        switch self {
        case .me:            return "__me__"
        case .friend(let f): return f.id
        }
    }
    var coordinate: Coordinate {
        switch self {
        case .me(let c, _, _):  return c
        case .friend(let f):    return f.coordinate
        }
    }
}

private struct FriendSelection: Identifiable { let id: String }

struct MapHomeView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var location: LocationManager

    @State private var region = MKCoordinateRegion(
        center: SampleData.cityCenter.clLocationCoordinate,
        span:   MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )
    @State private var selection: FriendSelection?
    @State private var showAddFriend   = false
    @State private var showFriends     = false
    @State private var showWeather     = false
    @State private var showReporting   = false
    @State private var didInitialCenter = false

    @State private var cityName    = ""
    @State private var temperature: Double? = nil
    @State private var weatherCode: Int? = nil
    @State private var ambientLayers = AmbientLayers()
    @State private var showAmbient   = false

    @State private var showSOSConfirm = false
    @State private var sosSending     = false
    @State private var sosSentBanner  = false
    @State private var showGhostInfo  = false

    private var entities: [MapEntity] {
        var list: [MapEntity] = []
        if let avatar = session.currentUser?.avatar {
            list.append(.me(location.effectiveCoordinate, avatar, session.currentUser?.isGhostMode ?? false))
        }
        list.append(contentsOf: session.friends.filter { !$0.isGhostMode }.map { .friend($0) })
        return list
    }

    private var ambient: AmbientState {
        AmbientState(
            timeOfDay: location.effectiveCoordinate.localTimeOfDay,
            season: Season.current(for: location.effectiveCoordinate),
            weather: WeatherCondition(wmoCode: weatherCode ?? -1),
            place: cityName.isEmpty ? "此地" : cityName
        )
    }

    private var ambientOverlay: some View {
        ZStack {
            if ambientLayers.dayNight {
                Rectangle().fill(ambient.timeOfDay.tint).opacity(ambient.timeOfDay.overlayOpacity)
            }
            if ambientLayers.weather {
                Rectangle().fill(ambient.weather.tint).opacity(ambient.weather.overlayOpacity)
            }
            if ambientLayers.season {
                Rectangle().fill(ambient.season.tint).opacity(ambient.season.overlayOpacity)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            map
                .ignoresSafeArea()

            ambientOverlay

            topLeftInfo
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, Theme.Spacing.lg)
                .padding(.top, 60)

            rightSidebar
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, Theme.Spacing.md)
                .padding(.top, 60)

            bottomPill
                .padding(.bottom, MapLayout.bottomPillBottom)

            ghostBanner
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, MapLayout.ghostBannerBottom)

            if sosSentBanner {
                sosSentToast
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 110)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            inviteSticker
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, Theme.Spacing.lg)
                .padding(.bottom, MapLayout.inviteStickerBottom)
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(item: $selection) { sel in
            FriendDetailSheet(friendId: sel.id, onOpenChat: {})
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendView().presentationDetents([.medium])
        }
        .sheet(isPresented: $showFriends) {
            NavigationStack { FriendsView() }
        }
        .sheet(isPresented: $showWeather) {
            WeatherDetailView(
                temperature: temperature ?? 0,
                cityName: cityName,
                coordinate: location.effectiveCoordinate,
                accuracy: location.accuracyMeters
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showReporting) {
            ReportingSettingsView().presentationDetents([.large])
        }
        .sheet(isPresented: $showAmbient) {
            AmbientPanelView(layers: $ambientLayers, ambient: ambient)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showGhostInfo) {
            ghostInfoSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            location.requestPermission()
            location.start()
            centerOnMeIfNeeded()
            fetchCityName(for: location.effectiveCoordinate)
            if temperature == nil { fetchWeather(for: location.effectiveCoordinate) }
            if weatherCode == nil { loadWeatherCode(for: location.effectiveCoordinate) }
        }
        .onChange(of: location.userCoordinate) { coord in
            centerOnMeIfNeeded()
            guard let c = coord else { return }
            fetchCityName(for: c)
            if temperature == nil { fetchWeather(for: c) }
            if weatherCode == nil { loadWeatherCode(for: c) }
        }
    }

    // MARK: - Map

    private var map: some View {
        Map(coordinateRegion: $region,
            showsUserLocation: false,
            annotationItems: entities) { entity in
            MapAnnotation(coordinate: entity.coordinate.clLocationCoordinate) {
                switch entity {
                case .me(_, let avatar, let ghost):
                    SelfMapBubble(avatar: avatar, isGhostMode: ghost)
                        .onTapGesture { centerOnMe() }
                case .friend(let friend):
                    FriendMapBubble(
                        friend: friend,
                        isSelected: selection?.id == friend.id,
                        userCoordinate: location.effectiveCoordinate,
                        localTimeIcon: friend.isGhostMode ? nil : friend.coordinate.localTimeOfDay.systemImage,
                        localTimeLabel: friend.isGhostMode ? nil : "\(friend.coordinate.localHour)时",
                        localTimeTint: friend.isGhostMode ? nil : friend.coordinate.localTimeOfDay.tint
                    )
                    .onTapGesture { focus(on: friend) }
                }
            }
        }
    }

    // MARK: - Top-left info

    private var topLeftInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(cityName.isEmpty ? "定位中…" : cityName)
                .font(Theme.Typography.titleLarge())
                .foregroundStyle(Theme.Palette.textPrimary)
                .themedShadow(.floating)
                .allowsHitTesting(false)

            HStack(spacing: Theme.Spacing.sm) {
                Button { showWeather = true } label: {
                    Label(
                        temperature != nil
                            ? String(format: "%.1f°C", temperature!)
                            : "天气",
                        systemImage: "cloud.fill"
                    )
                    .font(Theme.Typography.caption(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.pressable(scale: 0.92))
                .accessibilityLabel(temperature != nil ? "温度 \(String(format: "%.1f", temperature!)) 度" : "天气")

                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "person.2.fill")
                        .font(Theme.Typography.symbol(11))
                    Text("好友地图")
                        .font(Theme.Typography.caption(.semibold))
                    Image(systemName: "chevron.down")
                        .font(Theme.Typography.symbol(9, .bold))
                }
                .foregroundStyle(Theme.Palette.textPrimary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .onTapGesture { showFriends = true }
                .accessibilityLabel("好友地图")
            }

            Button { showAmbient = true } label: {
                Label(ambient.timeOfDay.title, systemImage: ambient.timeOfDay.systemImage)
                    .font(Theme.Typography.caption(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.pressable(scale: 0.92))
            .accessibilityLabel("氛围地图: \(ambient.timeOfDay.title)")

            if location.accuracyMeters > 0 {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "scope").font(Theme.Typography.symbol(10))
                    Text("定位精度: \(location.accuracyMeters)m")
                        .font(Theme.Typography.caption2(.medium))
                    Image(systemName: "chevron.right").font(Theme.Typography.symbol(8, .bold))
                }
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.85))
                .padding(.horizontal, 10).padding(.vertical, Theme.Spacing.xs)
                .background(Color.white.opacity(0.14), in: Capsule())
                .onTapGesture { showReporting = true }
            }
        }
    }

    // MARK: - Right sidebar

    private var rightSidebar: some View {
        VStack(spacing: 10) {
            Button { showAddFriend = true } label: {
                sidebarButton(icon: "plus", color: .white)
            }
            .buttonStyle(.pressable(scale: 0.88))
            .accessibilityLabel("添加好友")

            ForEach(session.friends.filter { !$0.isGhostMode }.prefix(4)) { friend in
                Button { focus(on: friend) } label: {
                    AvatarView(config: friend.avatar, size: 44, showsRing: true,
                               ringColor: selection?.id == friend.id ? Theme.Palette.sky : .white)
                        .shadowFloating()
                }
                .buttonStyle(.pressable(scale: 0.88))
                .accessibilityLabel("好友: \(friend.displayName)")
            }

            let hiddenFriends = session.friends.filter { $0.isGhostMode }
            if !hiddenFriends.isEmpty {
                Button {
                    Haptics.light()
                    showGhostInfo = true
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "moon.zzz.fill")
                            .font(Theme.Typography.symbol(11))
                        Text("\(hiddenFriends.count) 隐身")
                            .font(Theme.Typography.caption2(.semibold))
                        Image(systemName: "info.circle.fill")
                            .font(Theme.Typography.symbol(9))
                            .opacity(0.6)
                    }
                    .foregroundStyle(Theme.Palette.subtle)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 5)
                    .background(Theme.Palette.card.opacity(0.9), in: Capsule())
                }
                .buttonStyle(.pressable(scale: 0.88))
                .accessibilityLabel("\(hiddenFriends.count) 位好友隐身，点击了解详情")
            }

            Button(action: centerOnMe) {
                sidebarButton(icon: "location.fill", color: Theme.Palette.sky)
            }
            .buttonStyle(.pressable(scale: 0.88))
            .accessibilityLabel("定位到我的位置")

            Button {
                Haptics.light()
                showSOSConfirm = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.Palette.danger)
                        .frame(width: 44, height: 44)
                    if sosSending {
                        ProgressView().tint(Theme.Palette.textPrimary)
                    } else {
                        Text("SOS")
                            .font(Theme.Typography.subheadline(.heavy))
                            .foregroundStyle(Theme.Palette.textPrimary)
                    }
                }
                .themedShadow(.glow(Theme.Palette.danger))
            }
            .buttonStyle(.pressable(scale: 0.88))
            .disabled(sosSending)
            .accessibilityLabel("紧急求助 SOS")
        }
        .confirmationDialog("发出紧急求助？", isPresented: $showSOSConfirm, titleVisibility: .visible) {
            Button("立即向所有好友求助", role: .destructive) { sendSOS() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将把你的当前位置和求助消息发送给所有好友")
        }
    }

    // MARK: - 隐身说明 sheet（共用 GhostInfoView）

    private var ghostInfoSheet: some View {
        GhostInfoView()
    }

    private func sidebarButton(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(Theme.Typography.symbol(17, .semibold))
            .foregroundStyle(color)
            .frame(width: 44, height: 44)
            .background(Theme.Palette.card, in: Circle())
            .overlay(Circle().strokeBorder(Theme.Palette.separator, lineWidth: 0.5))
            .shadowFloating()
    }

    // MARK: - Bottom pill

    private var bottomPill: some View {
        Button { showFriends = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(Theme.Typography.caption(.semibold))
                Text("好友")
                    .font(Theme.Typography.callout(.bold))
            }
            .foregroundStyle(Theme.Palette.textPrimary)
            .padding(.horizontal, 22).padding(.vertical, 11)
            .background(Theme.Palette.card.opacity(0.92), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.Palette.separator, lineWidth: 0.5))
            .shadowFloating()
        }
        .buttonStyle(.pressable(scale: 0.92))
        .accessibilityLabel("好友列表")
    }

    // MARK: - 隐身提示

    private var ghostBanner: some View {
        Group {
            if session.currentUser?.isGhostMode == true {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "moon.zzz.fill")
                        .font(Theme.Typography.callout(.semibold))
                    Text("你已隐身 · 好友看不到你的实时位置")
                        .font(Theme.Typography.subheadline(.semibold))
                }
                .foregroundStyle(Theme.Palette.textPrimary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 9)
                .background(Color.black.opacity(0.62), in: Capsule())
                .shadowFloating()
                .accessibilityLabel("你已隐身")
            }
        }
    }

    // MARK: - Invite sticker

    private var inviteSticker: some View {
        Button { showAddFriend = true } label: {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(Theme.brandGradient)
                        .frame(width: 52, height: 52)
                    Image(systemName: "person.badge.plus")
                        .font(Theme.Typography.symbol(22, .bold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
                .themedShadow(.glow(Theme.Palette.primary))

                Text("邀请")
                    .font(Theme.Typography.caption2(.bold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.55), in: Capsule())
            }
        }
        .buttonStyle(.pressable(scale: 0.88))
        .accessibilityLabel("邀请好友")
    }

    // MARK: - SOS sent toast

    private var sosSentToast: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(Theme.Typography.body(.semibold))
            Text("求助已发出 · 好友会在聊天中看到你的位置")
                .font(Theme.Typography.subheadline(.semibold))
        }
        .foregroundStyle(Theme.Palette.textPrimary)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 9)
        .background(Theme.Palette.danger.opacity(0.92), in: Capsule())
        .shadowFloating()
    }

    private func sendSOS() {
        guard !sosSending else { return }
        sosSending = true
        Haptics.light()
        Task {
            let ok = await session.sendSOS(at: location.effectiveCoordinate)
            sosSending = false
            if ok {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { sosSentBanner = true }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation(.easeOut(duration: 0.25)) { sosSentBanner = false }
            }
        }
    }

    // MARK: - Actions

    private func focus(on friend: Friend) {
        Haptics.light()
        withAnimation(.spring(response: 0.40, dampingFraction: 0.82)) {
            region = MKCoordinateRegion(
                center: friend.coordinate.clLocationCoordinate,
                span:   MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
            )
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            selection = FriendSelection(id: friend.id)
        }
    }

    private func centerOnMe() {
        Haptics.light()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            region = MKCoordinateRegion(
                center: location.effectiveCoordinate.clLocationCoordinate,
                span:   MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            )
        }
    }

    private func centerOnMeIfNeeded() {
        guard !didInitialCenter, location.userCoordinate != nil else { return }
        didInitialCenter = true
        centerOnMe()
    }

    // MARK: - Data fetching

    private func fetchCityName(for coord: Coordinate) {
        let geocoder = CLGeocoder()
        let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        geocoder.reverseGeocodeLocation(loc) { placemarks, _ in
            DispatchQueue.main.async {
                if let p = placemarks?.first,
                   let name = (p.locality ?? p.subLocality ?? p.name), !name.isEmpty {
                    cityName = name
                } else if cityName.isEmpty {
                    cityName = "我的附近"
                }
            }
        }
    }

    private func fetchWeather(for coord: Coordinate) {
        Task {
            let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(coord.latitude)&longitude=\(coord.longitude)&current=temperature_2m"
            guard let url = URL(string: urlStr),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any],
                  let temp = current["temperature_2m"] as? Double else { return }
            await MainActor.run { temperature = temp }
        }
    }

    private func loadWeatherCode(for coord: Coordinate) {
        Task {
            let code = await fetchWeatherCode(for: coord)
            await MainActor.run { weatherCode = code }
        }
    }
}
