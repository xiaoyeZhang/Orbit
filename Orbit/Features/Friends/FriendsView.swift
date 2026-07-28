import SwiftUI
import OrbitCore
import OrbitUI
import OrbitServices

struct FriendsView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var query       = ""
    @State private var selection: String?
    @State private var showAdd     = false

    // 城市脉搏（泛社交发现流）
    @State private var pulse: CityPulse?
    @State private var pulseLoading = false

    private var filtered: [Friend] {
        guard !query.isEmpty else { return session.friends }
        return session.friends.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }
    private var favorites: [Friend] { filtered.filter { $0.isFavorite } }
    private var others:    [Friend] { filtered.filter { !$0.isFavorite } }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    inviteCard
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 14)
                        .popIn(delay: 0)

                    cityPulseSection
                        .padding(.bottom, 14)

                    if !favorites.isEmpty {
                        sectionBlock(title: "关注", friends: favorites, offset: 0)
                    }

                    sectionBlock(title: favorites.isEmpty ? "好友" : "全部好友",
                                 friends: others,
                                 offset: favorites.count)
                }
                .padding(.bottom, 10)
            }
            .background(Theme.Palette.groupedBackground.ignoresSafeArea())
            .searchable(text: $query, prompt: "搜索好友")
            .navigationTitle("好友")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.Palette.primary)
                    }
                    .buttonStyle(.pressable(scale: 0.88))
                }
            }
            .sheet(item: Binding(get: { selection.map(IDWrap.init) },
                                 set: { selection = $0?.id })) { wrap in
                FriendDetailSheet(friendId: wrap.id)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAdd) {
                AddFriendView().presentationDetents([.medium])
            }
            .overlay {
                if session.friends.isEmpty { emptyState }
            }
        }
    }

    // MARK: - 分区块
    private func sectionBlock(title: String, friends: [Friend], offset: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Palette.subtle)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)

            VStack(spacing: 1) {
                ForEach(Array(friends.enumerated()), id: \.element.id) { idx, friend in
                    friendRow(friend)
                        .staggeredAppear(index: offset + idx)

                    if idx < friends.count - 1 {
                        Divider().padding(.leading, 78)
                    }
                }
            }
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: - 好友行
    private func friendRow(_ friend: Friend) -> some View {
        Button { selection = friend.id } label: {
            HStack(spacing: 14) {
                // 头像 + 在线点
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(config: friend.avatar, size: 52,
                               showsRing: true,
                               ringColor: friend.isFavorite ? Theme.Palette.accent : .white)
                    if !friend.isGhostMode {
                        OnlineDot(size: 11)
                            .offset(x: 2, y: 2)
                    }
                }

                // 名字 + 位置
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(friend.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.Palette.ink)
                        if friend.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.Palette.accent)
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 10))
                        Text(friend.isGhostMode ? "隐身中" : friend.locationName)
                            .lineLimit(1)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Palette.subtle)
                }

                Spacer(minLength: 0)

                // 状态徽章
                VStack(alignment: .trailing, spacing: 5) {
                    BatteryBadge(presence: friend.presence, compact: true)
                    MovementChip(presence: friend.presence)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.pressable(scale: 0.94))
        .swipeActions(edge: .leading) {
            Button {
                Task { await session.toggleFavorite(friend) }
            } label: {
                Label(friend.isFavorite ? "取消关注" : "关注", systemImage: "star.fill")
            }
            .tint(Theme.Palette.accent)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await session.removeFriend(friend) }
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    // MARK: - 邀请卡
    private var inviteCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(0.22))
                    .frame(width: 50, height: 50)
                Image(systemName: "qrcode")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("我的邀请码")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(session.currentUser?.inviteCode ?? "—")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(2)
            }

            Spacer()

            Button {
                showAdd = true
                Haptics.medium()
            } label: {
                Text("添加好友")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Palette.primary)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(.pressable(scale: 0.92))
        }
        .padding(16)
        .gradientCard(Theme.brandGradient, cornerRadius: 20)
    }

    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Theme.Palette.subtle.opacity(0.6))
                .floating(amount: 8, duration: 3.5)
            Text("还没有好友")
                .font(.title3.bold())
                .foregroundStyle(Theme.Palette.ink)
            Text("点右上角发出邀请吧")
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.subtle)
        }
        .popIn()
    }

    // MARK: - 城市脉搏（泛社交发现流）
    private var cityPulseSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("城市脉搏")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.Palette.ink)
                    Text("附近的人与同城活动")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Palette.subtle)
                }
                Spacer()
            }
            .padding(.horizontal, 16)

            // 隐私总开关
            Picker("可见性", selection: $session.cityPulseVisibility) {
                ForEach(CityPulseVisibility.allCases) { v in
                    Text(v.label).tag(v)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .onChange(of: session.cityPulseVisibility) { _ in
                Task { await session.setCityPulseVisibility(session.cityPulseVisibility); await refreshPulse() }
            }

            if session.cityPulseVisibility == .off {
                offState
            } else if pulseLoading {
                loadingRow
            } else if let pulse {
                if !pulse.nearby.isEmpty { nearbyRow(pulse) }
                if !pulse.events.isEmpty { eventsRow(pulse) }
            }
        }
        .padding(.vertical, 16)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
        .padding(.horizontal, 16)
        .task { await refreshPulse() }
    }

    private func nearbyRow(_ pulse: CityPulse) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(pulse.nearby) { person in
                    nearbyCard(person)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func nearbyCard(_ p: NearbyPerson) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                AvatarView(config: p.avatar, size: 44, showsRing: false, ringColor: .clear)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ink)
                    Text(String(format: "%.1f km", p.distanceKm))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Palette.subtle)
                }
            }
            if !p.mutualFriends.isEmpty {
                Text("共同好友 · " + p.mutualFriends.joined(separator: "、"))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Palette.subtle)
                    .lineLimit(1)
            }
            Text(p.lastSeenText)
                .font(.system(size: 11))
                .foregroundStyle(Theme.Palette.subtle)
            Button {
                Haptics.medium()
                Toast.show("已向 \(p.displayName) 发出招呼（演示）")
            } label: {
                Text("打招呼")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Theme.Palette.accent, in: Capsule())
            }
            .buttonStyle(.pressable(scale: 0.94))
        }
        .padding(12)
        .frame(width: 168)
        .background(Theme.Palette.groupedBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func eventsRow(_ pulse: CityPulse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("同城活动")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Palette.subtle)
                .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(pulse.events) { ev in
                        eventCard(ev)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func eventCard(_ ev: CityEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(ev.emoji).font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text(ev.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ink)
                    Text(ev.category)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Palette.subtle)
                }
            }
            Text(ev.placeName)
                .font(.system(size: 12))
                .foregroundStyle(Theme.Palette.subtle)
            Text(ev.startsIn)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.Palette.accent)
            HStack(spacing: 4) {
                Image(systemName: "person.2").font(.system(size: 11))
                Text("\(ev.attendees) 人感兴趣")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Palette.subtle)
            }
            Button {
                Haptics.medium()
                Toast.show("已标记感兴趣：\(ev.title)（演示）")
            } label: {
                Text("感兴趣")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Theme.Palette.groupedBackground, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.Palette.accent, lineWidth: 1))
            }
            .buttonStyle(.pressable(scale: 0.94))
        }
        .padding(12)
        .frame(width: 168)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var offState: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye.slash")
                .font(.system(size: 18))
                .foregroundStyle(Theme.Palette.subtle)
            VStack(alignment: .leading, spacing: 2) {
                Text("城市脉搏已关闭")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Palette.ink)
                Text("打开后，可在不暴露给陌生人的前提下发现附近的人与活动")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Palette.subtle)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var loadingRow: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small).tint(Theme.Palette.accent)
            Text("正在感知附近的城市脉搏…")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Palette.subtle)
        }
        .padding(.horizontal, 16)
    }

    private func refreshPulse() async {
        pulseLoading = true
        if let p = await session.generateCityPulse() { pulse = p }
        pulseLoading = false
    }
}

private struct IDWrap: Identifiable { let id: String }
