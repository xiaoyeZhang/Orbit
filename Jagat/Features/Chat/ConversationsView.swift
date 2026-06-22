import SwiftUI
import OrbitCore
import OrbitUI
import OrbitServices

struct ConversationsView: View {
    @EnvironmentObject private var session: SessionStore

    private var sorted: [Conversation] {
        session.conversations.sorted { $0.lastMessageDate > $1.lastMessageDate }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sorted.isEmpty {
                    emptyState
                } else {
                    conversationList
                }
            }
            .background(Theme.Palette.groupedBackground.ignoresSafeArea())
            .navigationTitle("消息")
        }
    }

    // MARK: - 列表
    private var conversationList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 1) {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, convo in
                    NavigationLink {
                        ChatView(conversation: convo)
                    } label: {
                        conversationRow(convo)
                            .staggeredAppear(index: idx)
                    }
                    .buttonStyle(.pressable(scale: 0.97))

                    if idx < sorted.count - 1 {
                        Divider().padding(.leading, 82)
                    }
                }
            }
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
    }

    // MARK: - 会话行
    private func conversationRow(_ convo: Conversation) -> some View {
        HStack(spacing: 14) {
            // 头像 + 在线点
            ZStack(alignment: .bottomTrailing) {
                AvatarView(config: convo.friendAvatar, size: 54, showsRing: true)
                OnlineDot(size: 12).offset(x: 2, y: 2)
            }

            // 名字 + 预览
            VStack(alignment: .leading, spacing: 5) {
                Text(convo.friendName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Palette.ink)

                Text(convo.lastMessagePreview.isEmpty ? "开始聊天吧 👋" : convo.lastMessagePreview)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Palette.subtle)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // 时间 + 未读
            VStack(alignment: .trailing, spacing: 6) {
                Text(convo.lastMessageDate.relativeShort)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Palette.subtle)

                if convo.unreadCount > 0 {
                    Text(convo.unreadCount > 9 ? "9+" : "\(convo.unreadCount)")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(
                            Capsule().fill(Theme.Palette.accent)
                                .shadow(color: Theme.Palette.accent.opacity(0.45), radius: 5, y: 2)
                        )
                        .popIn()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Theme.Palette.subtle.opacity(0.55))
                .floating(amount: 7, duration: 3.8)
            Text("还没有消息")
                .font(.title3.bold())
                .foregroundStyle(Theme.Palette.ink)
            Text("在地图或好友页点开好友\n即可发起聊天 💬")
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.subtle)
                .multilineTextAlignment(.center)
        }
        .popIn()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
