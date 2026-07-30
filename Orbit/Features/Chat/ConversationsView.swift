import SwiftUI
import OrbitCore
import OrbitUI
import OrbitServices
import UserNotifications

struct ConversationsView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var searchText = ""
    @State private var pushChat: Conversation?
    @State private var showNotificationBanner = true
    @State private var showNewChat = false
    @State private var showFriends = false
    @State private var notice: NoticeItem?
    @State private var initiallyLoading = true

    private var sorted: [Conversation] {
        let all = session.conversations.sorted { $0.lastMessageDate > $1.lastMessageDate }
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.friendName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)
                        .padding(.bottom, Theme.Spacing.md)

                    if showNotificationBanner {
                        notificationBanner
                            .padding(.horizontal, Theme.Spacing.lg)
                    }

                    categoryList
                        .padding(.top, Theme.Spacing.xs)

                    if !sorted.isEmpty {
                        LazyVStack(spacing: 1) {
                            ForEach(sorted) { convo in
                                Button {
                                    pushChat = convo
                                } label: {
                                    conversationRow(convo)
                                }
                                .buttonStyle(.pressable(scale: 0.94))
                            }
                        }
                        .padding(.top, Theme.Spacing.xs)
                    } else if initiallyLoading {
                        convoSkeletonList
                            .padding(.top, Theme.Spacing.xs)
                    } else {
                        emptyDMs
                            .padding(.top, 36)
                    }

                    Color.clear.frame(height: 100)
                }
            }

            bottomSearchBar
        }
        .background(Theme.Palette.bg)
        .sheet(item: $pushChat) { convo in
            NavigationStack { ChatView(conversation: convo) }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            initiallyLoading = false
        }
    }

    // MARK: - Notification banner

    private var notificationBanner: some View {
        HStack(spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "bell.fill")
                    .font(Theme.Typography.symbol(16))
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text("点击开启通知权限，不错过任何互动消息")
                    .font(Theme.Typography.subheadline(.medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .onTapGesture { requestNotificationPermission() }

            Spacer()
            Button {
                withAnimation { showNotificationBanner = false }
            } label: {
                Image(systemName: "xmark")
                    .font(Theme.Typography.caption(.semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    Toast.show("通知已开启 🔔")
                } else {
                    Toast.show("通知权限未开启", icon: "bell.slash.fill")
                }
                withAnimation { showNotificationBanner = false }
            }
        }
    }

    // MARK: - Category list

    private var categoryList: some View {
        VStack(spacing: 1) {
            categoryRow(
                emoji: "🤝", label: "群聊", sub: "你已保存0个群组", badge: nil
            ) { Toast.show("群组功能即将上线 🚧") }
            categoryRow(
                emoji: "🙋", label: "好友申请", sub: "在这里添加新好友", badge: nil
            ) { showFriends = true }
            categoryRow(
                emoji: "🎉", label: "活动通知",
                sub: "恭喜挑战赛第四期的摸鱼...",
                badge: session.totalUnread > 0 ? session.totalUnread : nil,
                date: "06-17"
            ) {
                notice = NoticeItem(title: "活动通知",
                                    body: "恭喜挑战赛第四期的摸鱼大赛圆满收官，点击查看你的专属成绩与奖品领取方式～")
            }
            categoryRow(
                emoji: "⚙️", label: "系统通知",
                sub: "再不记录帮你叫医生了！",
                badge: session.totalUnread > 0 ? session.totalUnread : nil,
                date: "06-17", last: true
            ) {
                notice = NoticeItem(title: "系统通知",
                                    body: "再不记录位置，系统就要帮你呼叫医生啦！记得经常打开 App 留下你的足迹哦。")
            }
        }
        .background(Theme.Palette.card)
    }

    private func categoryRow(emoji: String, label: String, sub: String,
                             badge: Int?, date: String? = nil, last: Bool = false,
                             action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Text(emoji)
                    .font(Theme.Typography.title2())
                    .frame(width: 48, height: 48)
                    .background(Theme.Palette.card2, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(Theme.Typography.body(.semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(sub)
                        .font(Theme.Typography.subheadline())
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    if let date {
                        Text(date)
                            .font(Theme.Typography.caption())
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    if let badge, badge > 0 {
                        Text("\(min(badge, 99))")
                            .font(Theme.Typography.caption2(.heavy))
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Theme.Palette.accent, in: Capsule())
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.listRowV)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if !last {
                    Rectangle()
                        .fill(Theme.Palette.separator)
                        .frame(height: 0.5)
                        .padding(.leading, Theme.Spacing.listDividerLeading)
                }
            }
        }
        .buttonStyle(.pressable(scale: 0.94))
    }

    // MARK: - Conversation row

    private func conversationRow(_ convo: Conversation) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(config: convo.friendAvatar, size: 50, showsRing: true)
                OnlineDot(size: 10).offset(x: 2, y: 2)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(convo.friendName)
                    .font(Theme.Typography.body(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(convo.lastMessagePreview.isEmpty ? "开始聊天吧 👋" : convo.lastMessagePreview)
                    .font(Theme.Typography.subheadline())
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 6) {
                Text(convo.lastMessageDate.relativeShort)
                    .font(Theme.Typography.caption2(.medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                if convo.unreadCount > 0 {
                    Text(convo.unreadCount > 9 ? "9+" : "\(convo.unreadCount)")
                        .font(Theme.Typography.caption2(.heavy))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Theme.Palette.accent, in: Capsule())
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.listRowV)
        .background(Theme.Palette.card)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.Palette.separator)
                .frame(height: 0.5)
                .padding(.leading, Theme.Spacing.listDividerLeading)
        }
    }

    // MARK: - Skeleton

    private var convoSkeletonList: some View {
        VStack(spacing: 1) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: Theme.Spacing.md) {
                    SkeletonBlock(height: 48, shape: .circle)
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonBlock(width: 120, height: 13, shape: .line(height: 13))
                        SkeletonBlock(width: 180, height: 11, shape: .line(height: 11))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        SkeletonBlock(width: 40, height: 10, shape: .line(height: 10))
                        SkeletonBlock(width: 18, height: 18, shape: .circle)
                    }
                }
                .padding(.vertical, 13)
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }

    // MARK: - Empty DMs

    private var emptyDMs: some View {
        EmptyStateView(
            icon: "bubble.left.and.bubble.right",
            title: "还没有私信",
            subtitle: "在地图上点一位好友，就能和 TA 聊起来",
            tint: Theme.Palette.sky
        )
        .popIn()
        .accessibilityLabel("还没有私信")
    }

    // MARK: - Bottom search bar

    private var bottomSearchBar: some View {
        HStack(spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(Theme.Typography.callout())
                    .foregroundStyle(Theme.Palette.textSecondary)
                TextField("搜索", text: $searchText)
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .tint(Theme.Palette.primary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 11)
            .background(Theme.Palette.card2, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.Palette.separator, lineWidth: 0.5))

            Button { showNewChat = true } label: {
                Image(systemName: "square.and.pencil")
                    .font(Theme.Typography.symbol(17, .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Theme.Palette.primary, in: Circle())
            }
            .accessibilityLabel("发起新对话")
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.xl)
        .background(
            LinearGradient(colors: [Theme.Palette.bg.opacity(0), Theme.Palette.bg],
                           startPoint: .top, endPoint: .bottom)
                .padding(.top, -Theme.Spacing.xxl)
                .ignoresSafeArea()
        )
        .sheet(isPresented: $showNewChat) {
            AddFriendView().presentationDetents([.medium])
        }
        .sheet(isPresented: $showFriends) {
            NavigationStack { FriendsView() }
        }
        .sheet(item: $notice) { item in
            NoticeSheet(title: item.title, bodyText: item.body)
        }
    }
}

private struct NoticeItem: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

private struct NoticeSheet: View {
    let title: String
    let bodyText: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                Text(bodyText)
                    .font(Theme.Typography.callout())
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineSpacing(5)
                    .padding(Theme.Spacing.xl)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(Theme.Palette.primary)
                }
            }
            .background(Theme.Palette.bg)
        }
    }
}
