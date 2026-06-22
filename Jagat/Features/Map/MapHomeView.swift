import SwiftUI
import MapKit
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
    @State private var showAddFriend = false
    @State private var didInitialCenter = false
    @State private var carouselShown = false

    private var entities: [MapEntity] {
        var list: [MapEntity] = []
        if let avatar = session.currentUser?.avatar {
            list.append(.me(location.effectiveCoordinate, avatar))
        }
        list.append(contentsOf: session.friends.map { .friend($0) })
        return list
    }

    var body: some View {
        // 用 overlay(alignment:) 叠加 UI，避免 VStack+Spacer 撑高 topBar
        map
            .overlay(alignment: .top) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
            }
            .overlay(alignment: .bottomTrailing) {
                locateButton
                    .padding(.trailing, 16)
                    .padding(.bottom, carouselShown ? 150 : 130)
            }
            .overlay(alignment: .bottom) {
                if !session.friends.isEmpty {
                    friendCarousel
                        .offset(y: carouselShown ? 0 : 80)
                        .opacity(carouselShown ? 1 : 0)
                        .padding(.bottom, 122)
                }
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
            .onAppear {
                location.requestPermission()
                location.start()
                centerOnMeIfNeeded()
                withAnimation(.spring(response: 0.55, dampingFraction: 0.80).delay(0.25)) {
                    carouselShown = true
                }
            }
            .onChange(of: location.userCoordinate) { _ in centerOnMeIfNeeded() }
    }

    // MARK: - 地图
    private var map: some View {
        Map(coordinateRegion: $region,
            showsUserLocation: false,
            annotationItems: entities) { entity in
            MapAnnotation(coordinate: entity.coordinate.clLocationCoordinate) {
                switch entity {
                case .me(_, let avatar):
                    SelfMapBubble(avatar: avatar)
                        .onTapGesture { centerOnMe() }
                        .background(.clear)
                case .friend(let friend):
                    FriendMapBubble(friend: friend, isSelected: selection?.id == friend.id)
                        .onTapGesture { focus(on: friend) }
                        .background(.clear)
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - 顶部栏
    private var topBar: some View {
        HStack(spacing: 10) {
            if let user = session.currentUser {
                Button { centerOnMe() } label: {
                    AvatarView(config: user.avatar, size: 36, showsRing: true)
                        .shadow(color: Theme.Palette.primary.opacity(0.25), radius: 5, y: 2)
                }
                .buttonStyle(.pressable(scale: 0.88))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("你好，\(session.currentUser?.displayName ?? "我")")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(.label))
                HStack(spacing: 4) {
                    OnlineDot(size: 6)
                    Text("\(session.friends.count) 位好友在线")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }

            Spacer()

            Button { showAddFriend = true } label: {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Palette.primary)
                    .frame(width: 34, height: 34)
                    .background {
                        Circle()
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
                    }
            }
            .buttonStyle(.pressable(scale: 0.88))
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Theme.Palette.primary.opacity(0.18), lineWidth: 1.0)
                }
                .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
        }
    }

    // MARK: - 定位按钮
    private var locateButton: some View {
        Button(action: centerOnMe) {
            ZStack {
                Circle()
                    .fill(Theme.brandGradient)
                    .frame(width: 46, height: 46)
                    .shadow(color: Theme.Palette.primary.opacity(0.40), radius: 10, y: 4)
                Image(systemName: "location.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.pressable(scale: 0.88))
    }

    // MARK: - 好友横滑卡片
    private var friendCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(session.friends) { friend in
                    Button { focus(on: friend) } label: {
                        friendCard(friend)
                    }
                    .buttonStyle(.pressable(scale: 0.93))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(height: 108)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(.white.opacity(0.35), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.12), radius: 20, y: -4)
        }
        .padding(.horizontal, 10)
    }

    private func friendCard(_ friend: Friend) -> some View {
        let isSelected = selection?.id == friend.id
        return VStack(spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(config: friend.avatar, size: 50,
                           showsRing: true,
                           ringColor: isSelected ? Theme.Palette.primary : .white)
                    .shadow(color: isSelected ? Theme.Palette.primary.opacity(0.40) : .black.opacity(0.08),
                            radius: isSelected ? 8 : 4, y: 2)
                    .scaleEffect(isSelected ? 1.07 : 1.0)
                    .animation(.jelly, value: isSelected)

                if !friend.isGhostMode {
                    OnlineDot(size: 8).offset(x: 2, y: 2)
                }
            }

            Text(friend.displayName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.Palette.primary : Color(.label))
                .lineLimit(1)

            MovementChip(presence: friend.presence)
                .scaleEffect(0.75)
                .frame(height: 14)
        }
        .frame(width: 62)
    }

    // MARK: - 行为
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
}
