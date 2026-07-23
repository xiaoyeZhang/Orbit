import SwiftUI
import MapKit
import CoreLocation
import OrbitCore
import OrbitUI
import OrbitServices

private enum MapEntity: Identifiable {
    case me(Coordinate, AvatarConfig)
    case friend(Friend)

    var id: String {
        switch self {
        case .me:            return "__me__"
        case .friend(let f): return f.id
        }
    }
    var coordinate: Coordinate {
        switch self {
        case .me(let c, _):  return c
        case .friend(let f): return f.coordinate
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

    private var entities: [MapEntity] {
        var list: [MapEntity] = []
        if let avatar = session.currentUser?.avatar {
            list.append(.me(location.effectiveCoordinate, avatar))
        }
        list.append(contentsOf: session.friends.map { .friend($0) })
        return list
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Map ──
            map
                .ignoresSafeArea()

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
        .onAppear {
            location.requestPermission()
            location.start()
            centerOnMeIfNeeded()
            fetchCityName(for: location.effectiveCoordinate)
            if temperature == nil { fetchWeather(for: location.effectiveCoordinate) }
        }
        .onChange(of: location.userCoordinate) { coord in
            centerOnMeIfNeeded()
            guard let c = coord else { return }
            fetchCityName(for: c)
            if temperature == nil { fetchWeather(for: c) }
        }
    }

    // MARK: - Map
    private var map: some View {
        Map(coordinateRegion: $region,
            showsUserLocation: false,
            annotationItems: entities) { entity in
            MapAnnotation(coordinate: entity.coordinate.clLocationCoordinate) {
                switch entity {
                case .me(_, let avatar):
                    SelfMapBubble(avatar: avatar)
                        .onTapGesture { centerOnMe() }
                case .friend(let friend):
                    FriendMapBubble(
                        friend: friend,
                        isSelected: selection?.id == friend.id,
                        userCoordinate: location.effectiveCoordinate
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
                    if let t = temperature {
                        Label(String(format: "%.1f°C", t), systemImage: "cloud.fill")
                    } else {
                        Label("天气", systemImage: "cloud.fill")
                    }
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

            // Friend avatars (first 4)
            ForEach(session.friends.prefix(4)) { friend in
                Button { focus(on: friend) } label: {
                    AvatarView(config: friend.avatar, size: 44, showsRing: true,
                               ringColor: selection?.id == friend.id ? Theme.Palette.sky : .white)
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                }
                .buttonStyle(.pressable(scale: 0.88))
            }

            // Locate me
            Button(action: centerOnMe) {
                sidebarButton(icon: "location.fill", color: Theme.Palette.sky)
            }
            .buttonStyle(.pressable(scale: 0.88))
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
}
