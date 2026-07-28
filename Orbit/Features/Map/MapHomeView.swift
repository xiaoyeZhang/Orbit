import SwiftUI
import MapKit
import CoreLocation
import OrbitCore
import OrbitUI
import OrbitServices

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

    // Top-left info
    @State private var cityName    = ""
    @State private var temperature: Double? = nil
    @State private var weatherCode: Int? = nil
    @State private var ambientLayers = AmbientLayers()
    @State private var showAmbient   = false

    // SOS 一键求助
    @State private var showSOSConfirm = false
    @State private var sosSending     = false
    @State private var sosSentBanner  = false

    private var entities: [MapEntity] {
        var list: [MapEntity] = []
        if let avatar = session.currentUser?.avatar {
            // 自己始终在地图中心；隐身状态传给气泡仅用于视觉反馈
            list.append(.me(location.effectiveCoordinate, avatar, session.currentUser?.isGhostMode ?? false))
        }
        // 隐身好友不进入地图：不暴露其真实位置（对齐“隐身 = 对方看不到我”的语义）
        list.append(contentsOf: session.friends.filter { !$0.isGhostMode }.map { .friend($0) })
        return list
    }

    // 当前氛围快照（天气 / 昼夜 / 季节）
    private var ambient: AmbientState {
        AmbientState(
            timeOfDay: location.effectiveCoordinate.localTimeOfDay,
            season: Season.current(for: location.effectiveCoordinate),
            weather: WeatherCondition(wmoCode: weatherCode ?? -1),
            place: cityName.isEmpty ? "此地" : cityName
        )
    }

    // 地图氛围叠层（按开启的图层分别叠加，位于地图之上、UI 之下）
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
            // ── Map ──
            map
                .ignoresSafeArea()

            // ── Ambient overlay (weather / day-night / season) ──
            ambientOverlay

            // ── Top-left: city + weather + accuracy ──
            topLeftInfo
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 16)
                .padding(.top, 60)

            // ── Right sidebar ──
            rightSidebar
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 12)
                .padding(.top, 60)

            // ── Bottom "好友" pill ──
            bottomPill
                .padding(.bottom, 120)

            // ── 隐身状态提示（自己隐身时显示）──
            ghostBanner
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 72)

            // ── SOS 已发送提示 ──
            if sosSentBanner {
                sosSentToast
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 110)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // ── Invite sticker (bottom-left) ──
            inviteSticker
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 16)
                .padding(.bottom, 136)
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
            NavigationStack {
                FriendsView()
            }
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
            ReportingSettingsView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showAmbient) {
            AmbientPanelView(layers: $ambientLayers, ambient: ambient)
                .presentationDetents([.medium])
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

    // MARK: - Top-left info block
    private var topLeftInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            // City name
            Text(cityName.isEmpty ? "定位中…" : cityName)
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 6, y: 2)
                .allowsHitTesting(false)

            // Row: weather + map type
            HStack(spacing: 8) {
                Button { showWeather = true } label: {
                    Label(
                        temperature != nil
                            ? String(format: "%.1f°C", temperature!)
                            : "天气",
                        systemImage: "cloud.fill"
                    )
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.pressable(scale: 0.92))

                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11))
                    Text("好友地图")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .onTapGesture { showFriends = true }
            }

            // 氛围图层入口
            Button { showAmbient = true } label: {
                Label(ambient.timeOfDay.title, systemImage: ambient.timeOfDay.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.pressable(scale: 0.92))

            // Accuracy
            if location.accuracyMeters > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "scope").font(.system(size: 10))
                    Text("定位精度: \(location.accuracyMeters)m")
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.white.opacity(0.14), in: Capsule())
                .onTapGesture { showReporting = true }
            }
        }
    }

    // MARK: - Right sidebar
    private var rightSidebar: some View {
        VStack(spacing: 10) {
            // Add friend
            Button { showAddFriend = true } label: {
                sidebarButton(icon: "plus", color: .white)
            }
            .buttonStyle(.pressable(scale: 0.88))

            // Friend avatars（前 4 位可见好友；隐身好友不在地图，避免定位到其真实坐标）
            ForEach(session.friends.filter { !$0.isGhostMode }.prefix(4)) { friend in
                Button { focus(on: friend) } label: {
                    AvatarView(config: friend.avatar, size: 44, showsRing: true,
                               ringColor: selection?.id == friend.id ? Theme.Palette.sky : .white)
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                }
                .buttonStyle(.pressable(scale: 0.88))
            }

            // 隐身好友提示（让“好友没丢”有解释）
            let hiddenFriends = session.friends.filter { $0.isGhostMode }
            if !hiddenFriends.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 11))
                    Text("\(hiddenFriends.count) 隐身")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Theme.Palette.subtle)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Theme.Palette.card.opacity(0.9), in: Capsule())
            }

            // Locate me
            Button(action: centerOnMe) {
                sidebarButton(icon: "location.fill", color: Theme.Palette.sky)
            }
            .buttonStyle(.pressable(scale: 0.88))

            // SOS 一键求助
            Button {
                Haptics.light()
                showSOSConfirm = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.Palette.danger)
                        .frame(width: 44, height: 44)
                    if sosSending {
                        ProgressView().tint(.white)
                    } else {
                        Text("SOS")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
                .shadow(color: Theme.Palette.danger.opacity(0.5), radius: 8, y: 3)
            }
            .buttonStyle(.pressable(scale: 0.88))
            .disabled(sosSending)
        }
        .confirmationDialog("发出紧急求助？", isPresented: $showSOSConfirm, titleVisibility: .visible) {
            Button("立即向所有好友求助", role: .destructive) { sendSOS() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将把你的当前位置和求助消息发送给所有好友")
        }
    }

    private func sidebarButton(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 44, height: 44)
            .background(Theme.Palette.card, in: Circle())
            .overlay(Circle().strokeBorder(Theme.Palette.separator, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }

    // MARK: - Bottom pill
    private var bottomPill: some View {
        Button { showFriends = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                Text("好友")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22).padding(.vertical, 11)
            .background(Theme.Palette.card.opacity(0.92), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.Palette.separator, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.pressable(scale: 0.92))
    }

    // MARK: - 隐身提示（仅自己隐身时显示）
    private var ghostBanner: some View {
        Group {
            if session.currentUser?.isGhostMode == true {
                HStack(spacing: 8) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("你已隐身 · 好友看不到你的实时位置")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Color.black.opacity(0.62), in: Capsule())
                .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
            }
        }
    }

    // MARK: - Invite sticker
    private var inviteSticker: some View {
        Button { showAddFriend = true } label: {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [Color(hex: 0x6C5CE7), Color(hex: 0xFD79A8)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 52, height: 52)
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                .shadow(color: Theme.Palette.primary.opacity(0.5), radius: 10, y: 4)

                Text("邀请")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.black.opacity(0.55), in: Capsule())
            }
        }
        .buttonStyle(.pressable(scale: 0.88))
    }

    // MARK: - SOS 已发送提示条
    private var sosSentToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
            Text("求助已发出 · 好友会在聊天中看到你的位置")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(Theme.Palette.danger.opacity(0.92), in: Capsule())
        .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
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

// MARK: - 氛围地图设置面板（天气 / 昼夜 / 季节 图层开关）
private struct AmbientPanelView: View {
    @Binding var layers: AmbientLayers
    let ambient: AmbientState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    currentCard
                    layerToggle(title: "昼夜", subtitle: ambient.timeOfDay.title,
                                icon: ambient.timeOfDay.systemImage, color: ambient.timeOfDay.tint,
                                isOn: $layers.dayNight)
                    layerToggle(title: "天气", subtitle: ambient.weather.title,
                                icon: ambient.weather.systemImage, color: ambient.weather.tint,
                                isOn: $layers.weather)
                    layerToggle(title: "季节", subtitle: ambient.season.title,
                                icon: ambient.season.systemImage, color: ambient.season.tint,
                                isOn: $layers.season)
                    tipCard
                }
                .padding(16)
            }
            .background(Theme.Palette.groupedBackground.ignoresSafeArea())
            .navigationTitle("氛围地图")
            .navigationBarTitleDisplayMode(.inline)
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
        }
    }

    private var currentCard: some View {
        HStack(spacing: 12) {
            Image(systemName: ambient.timeOfDay.systemImage)
                .font(.system(size: 26))
                .foregroundStyle(ambient.timeOfDay.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(ambient.summary)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.Palette.ink)
                Text("天气、昼夜与季节会作为淡色图层叠加在地图上")
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.subtle)
            }
            Spacer()
        }
        .padding(16)
        .card()
    }

    private func layerToggle(title: String, subtitle: String, icon: String,
                             color: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.20)).frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Palette.ink)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(Theme.Palette.subtle)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .card()
    }

    private var tipCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Palette.subtle)
            Text("地图上的好友点位会按各自所在地的当地时间显示昼夜，异地好友此刻是白天还是夜晚一目了然。")
                .font(.caption)
                .foregroundStyle(Theme.Palette.subtle)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
    }
}
