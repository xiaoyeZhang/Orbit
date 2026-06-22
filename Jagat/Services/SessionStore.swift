import Foundation
import SwiftUI

/// App 的状态中枢：连接 `BackendService` 与 SwiftUI 视图。
///
/// 视图只观察这里的 `@Published` 数据，所有对后端的调用都经过它，
/// 因此切换 Mock / 真实后端时视图零改动。
@MainActor
final class SessionStore: ObservableObject {

    // 已发布状态
    @Published var currentUser: UserProfile?
    @Published var friends: [Friend] = []
    @Published var conversations: [Conversation] = []
    @Published var places: [Place] = []
    @Published var isAuthenticated = false
    @Published var isBusy = false
    @Published var errorMessage: String?

    let backend: BackendService
    private var friendsStreamTask: Task<Void, Never>?

    init(backend: BackendService) {
        self.backend = backend
        if let user = backend.currentUser() {
            currentUser = user
            isAuthenticated = true
        } else if ProcessInfo.processInfo.environment["JAGAT_AUTOLOGIN"] == "1" {
            // 演示 / UI 测试用：设环境变量 JAGAT_AUTOLOGIN=1 即跳过登录直达主界面。
            currentUser = UserProfile(
                id: "me", displayName: "我", bio: "在路上 🚀",
                avatar: AvatarConfig(skinTone: .medium, hair: .short, hairColor: .brown,
                                     accessory: .glasses, background: .violet),
                inviteCode: "ORBIT-ME01", phoneNumber: nil
            )
            isAuthenticated = true
        }
    }

    // MARK: - 鉴权
    func signIn(phone: String, code: String) async {
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do {
            let user = try await backend.signIn(phone: phone, code: code)
            currentUser = user
            isAuthenticated = true
            await bootstrap()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 请求短信验证码（Firebase 手机号登录的第一步；Mock 下为空操作直接返回成功）。
    func requestCode(phone: String) async -> Bool {
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do { try await backend.requestVerificationCode(phone: phone); return true }
        catch { errorMessage = error.localizedDescription; return false }
    }

    func signOut() {
        backend.signOut()
        friendsStreamTask?.cancel()
        friendsStreamTask = nil
        currentUser = nil
        friends = []
        conversations = []
        places = []
        isAuthenticated = false
    }

    // MARK: - 初始化数据 + 订阅实时流
    func bootstrap() async {
        do {
            async let f = backend.fetchFriends()
            async let c = backend.fetchConversations()
            async let p = backend.fetchPlaces()
            friends = try await f
            conversations = try await c
            places = try await p
        } catch {
            errorMessage = error.localizedDescription
        }
        subscribeFriends()
    }

    private func subscribeFriends() {
        friendsStreamTask?.cancel()
        friendsStreamTask = Task { [weak self] in
            guard let self else { return }
            for await updated in self.backend.friendsStream() {
                self.friends = updated
            }
        }
    }

    // MARK: - 好友操作
    func addFriend(code: String) async -> Bool {
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do {
            _ = try await backend.addFriend(inviteCode: code)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func toggleFavorite(_ friend: Friend) async {
        do { try await backend.setFavorite(friendId: friend.id, isFavorite: !friend.isFavorite) }
        catch { errorMessage = error.localizedDescription }
    }

    func removeFriend(_ friend: Friend) async {
        do { try await backend.removeFriend(id: friend.id) }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: - 资料
    func updateProfile(_ profile: UserProfile) async {
        do {
            try await backend.updateProfile(profile)
            currentUser = profile
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - 便捷查询
    func friend(by id: String) -> Friend? { friends.first { $0.id == id } }

    func conversation(forFriend friendId: String) -> Conversation? {
        conversations.first { $0.friendId == friendId }
    }

    /// 找到或新建与某好友的会话（用于从地图/好友页直接发起聊天）。
    /// 会话 ID 用「双方 ID 排序拼接」，保证两端指向同一会话文档（Firebase 聊天可互通）。
    func ensureConversation(for friend: Friend) -> Conversation {
        if let existing = conversation(forFriend: friend.id) { return existing }
        let pairId = [currentUser?.id ?? "me", friend.id].sorted().joined(separator: "_")
        let convo = Conversation(
            id: pairId,
            friendId: friend.id,
            friendName: friend.displayName,
            friendAvatar: friend.avatar,
            lastMessagePreview: "",
            lastMessageDate: Date(),
            unreadCount: 0
        )
        conversations.append(convo)
        return convo
    }

    var totalUnread: Int { conversations.reduce(0) { $0 + $1.unreadCount } }

    var favoriteFriends: [Friend] { friends.filter { $0.isFavorite } }
}
