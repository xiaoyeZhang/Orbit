import SwiftUI
import OrbitCore
import OrbitUI
import OrbitServices

struct FriendsView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var query       = ""
    @State private var selection: String?
    @State private var showAdd     = false

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
}

private struct IDWrap: Identifiable { let id: String }
