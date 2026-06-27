import SwiftUI
import OrbitCore
import OrbitUI
import OrbitServices

struct ConversationsView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var searchText = ""
    @State private var pushChat: Conversation?

    private var sorted: [Conversation] {
        let all = session.conversations.sorted { $0.lastMessageDate > $1.lastMessageDate }
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.friendName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Drag handle
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)
                        .padding(.bottom, 14)

                    // ── Notification permission banner ──
                    notificationBanner
                        .padding(.horizontal, 16)

                    // ── Category rows (vertical, reference-style) ──
                    categoryList
                        .padding(.top, 4)

                    // ── Private messages ──
                    if !sorted.isEmpty {
                        LazyVStack(spacing: 1) {
                            ForEach(sorted) { convo in
                                Button {
                                    pushChat = convo
                                } label: {
                                    conversationRow(convo)
                                }
                                .buttonStyle(.pressable(scale: 0.97))
                            }
                        }
                        .padding(.top, 4)
                    } else {
                        emptyDMs
                            .padding(.top, 36)
                    }

                    Color.clear.frame(height: 100)
                }
            }

            // ── Bottom search bar ──
            bottomSearchBar
        }
        .background(Theme.Palette.bg)
        .sheet(item: $pushChat) { convo in
            NavigationStack {
                ChatView(conversation: convo)
            }
        }
    }

    // MARK: - Notification banner
    private var notificationBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.system(size: 16))
                .foregroundStyle(Theme.Palette.textSecondary)
            Text("点击开启通知权限，不错过任何互动消息")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            Button {
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Category list (vertical rows like reference)
    private var categoryList: some View {
        VStack(spacing: 1) {
            categoryRow(
                emoji: "🤝",
                label: "群聊",
                sub: "你已保存0个群组",
                badge: nil
            )
            categoryRow(
                emoji: "🙋",
                label: "好友申请",
                sub: "在这里添加新好友",
                badge: nil
            )
            categoryRow(
                emoji: "🎉",
                label: "活动通知",
                sub: "恭喜挑战赛第四期的摸鱼...",
                badge: session.totalUnread > 0 ? session.totalUnread : nil,
                date: "06-17"
            )
            categoryRow(
                emoji: "⚙️",
                label: "系统通知",
                sub: "再不记录帮你叫医生了！",
                badge: session.totalUnread > 0 ? session.totalUnread : nil,
                date: "06-17",
                last: true
            )
        }
        .background(Theme.Palette.card)
    }

    private func categoryRow(emoji: String, label: String, sub: String,
                             badge: Int?, date: String? = nil, last: Bool = false,
                             action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(emoji)
                    .font(.system(size: 28))
                    .frame(width: 48, height: 48)
                    .background(Theme.Palette.card2, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(sub)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    if let date { Text(date).font(.system(size: 12)).foregroundStyle(Theme.Palette.textSecondary) }
                    if let badge, badge > 0 {
                        Text("\(min(badge, 99))")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Theme.Palette.accent, in: Capsule())
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if !last {
                    Rectangle().fill(Theme.Palette.separator).frame(height: 0.5).padding(.leading, 78)
                }
            }
        }
        .buttonStyle(.pressable(scale: 0.97))
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
            Rectangle().fill(Theme.Palette.separator).frame(height: 0.5).padding(.leading, 80)
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
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Theme.Palette.primary, in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .background(
            LinearGradient(colors: [Theme.Palette.bg.opacity(0), Theme.Palette.bg],
                           startPoint: .top, endPoint: .bottom)
                .padding(.top, -32)
                .ignoresSafeArea()
        )
    }
}
