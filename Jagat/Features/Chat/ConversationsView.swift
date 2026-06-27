import SwiftUI
import OrbitCore
import OrbitUI
import OrbitServices

struct ConversationsView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var searchText = ""

    private var sorted: [Conversation] {
        let all = session.conversations.sorted { $0.lastMessageDate > $1.lastMessageDate }
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.friendName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // ── Notification sections ──
                        notificationBanner
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        // ── Quick categories ──
                        categoryGrid
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        // ── Conversations / DMs ──
                        if !sorted.isEmpty {
                            sectionHeader(title: "私信")
                                .padding(.horizontal, 16)
                                .padding(.top, 20)

                            LazyVStack(spacing: 1) {
                                ForEach(sorted) { convo in
                                    NavigationLink {
                                        ChatView(conversation: convo)
                                    } label: {
                                        conversationRow(convo)
                                    }
                                    .buttonStyle(.pressable(scale: 0.97))
                                }
                            }
                            .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        } else {
                            emptyDMs
                                .padding(.top, 40)
                        }

                        Color.clear.frame(height: 120)
                    }
                }

                // ── Bottom search bar ──
                bottomSearchBar
            }
            .background(Theme.Palette.bg.ignoresSafeArea())
            .navigationTitle("消息")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Notification banner
    private var notificationBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.Palette.sunshine)
            VStack(alignment: .leading, spacing: 2) {
                Text("开启通知，不错过任何互动消息")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button("开启") {}
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.Palette.bg)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Theme.Palette.sunshine, in: Capsule())
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.Palette.sunshine.opacity(0.25), lineWidth: 0.5)
        )
    }

    // MARK: - Category grid
    private var categoryGrid: some View {
        HStack(spacing: 12) {
            categoryCell(icon: "person.badge.plus", label: "好友申请",
                         color: Theme.Palette.primary, count: 0)
            categoryCell(icon: "flag.fill", label: "活动通知",
                         color: Theme.Palette.mint, count: 0)
            categoryCell(icon: "gearshape.fill", label: "系统通知",
                         color: Theme.Palette.subtle, count: 0)
        }
    }

    private func categoryCell(icon: String, label: String, color: Color, count: Int) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 52, height: 52)
                    .background(color.opacity(0.15), in: Circle())

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Theme.Palette.accent, in: Circle())
                        .offset(x: 4, y: -4)
                }
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Section header
    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
        }
    }

    // MARK: - Conversation row
    private func conversationRow(_ convo: Conversation) -> some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(config: convo.friendAvatar, size: 50, showsRing: true)
                OnlineDot(size: 10).offset(x: 2, y: 2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(convo.friendName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Text(convo.lastMessagePreview.isEmpty ? "开始聊天吧 👋" : convo.lastMessagePreview)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 6) {
                Text(convo.lastMessageDate.relativeShort)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)

                if convo.unreadCount > 0 {
                    Text(convo.unreadCount > 9 ? "9+" : "\(convo.unreadCount)")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Theme.Palette.accent, in: Capsule())
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(Theme.Palette.card)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.Palette.separator)
                .frame(height: 0.5)
                .padding(.leading, 80)
        }
    }

    // MARK: - Empty DMs
    private var emptyDMs: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.Palette.textSecondary.opacity(0.4))
            Text("还没有私信")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
            Text("在地图上点击好友即可发起聊天")
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.textSecondary.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Bottom search bar
    private var bottomSearchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Palette.textSecondary)
                TextField("搜索", text: $searchText)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .tint(Theme.Palette.primary)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(Theme.Palette.card2, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.Palette.separator, lineWidth: 0.5))

            Button {
                // Compose new message
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Theme.Palette.primary, in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
        .background(
            LinearGradient(colors: [Theme.Palette.bg.opacity(0), Theme.Palette.bg],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}
