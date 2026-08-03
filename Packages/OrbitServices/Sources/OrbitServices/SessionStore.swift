import Foundation
import SwiftUI
import OrbitCore

@MainActor
public final class SessionStore: ObservableObject {

    @Published public var currentUser: UserProfile?
    @Published public var friends: [Friend] = []
    @Published public var conversations: [Conversation] = []
    @Published public var places: [Place] = []
    @Published public var cityPulseVisibility: CityPulseVisibility = .friendsOnly
    @Published public var intimateRelation: IntimateRelation?
    @Published public var isMember: Bool = false
    @Published public var isAuthenticated = false
    @Published public var isBusy = false
    @Published public var errorMessage: String?
    /// 列表级加载失败（区别于全局 errorMessage）。置非 nil 时，好友/会话等列表视图展示错误态而非内容。默认 nil。
    @Published public var loadError: String?

    public let backend: BackendService
    private var friendsStreamTask: Task<Void, Never>?

    public init(backend: BackendService) {
        self.backend = backend
        if let user = backend.currentUser() {
            currentUser = user; isAuthenticated = true
        } else if ProcessInfo.processInfo.environment["ORBIT_AUTOLOGIN"] == "1" {
            currentUser = UserProfile(
                id: "me", displayName: "我", bio: "在路上 🚀",
                avatar: AvatarConfig(skinTone: .medium, hair: .short, hairColor: .brown,
                                     accessory: .glasses, background: .violet),
                inviteCode: "ORBIT-ME01"
            )
            isAuthenticated = true
        }
    }

    // MARK: - Auth
    public func signIn(phone: String, code: String) async {
        isBusy = true; errorMessage = nil; defer { isBusy = false }
        do {
            let user = try await backend.signIn(phone: phone, code: code)
            currentUser = user; isAuthenticated = true
            await bootstrap()
        } catch { errorMessage = error.localizedDescription }
    }

    public func requestCode(phone: String) async -> Bool {
        isBusy = true; errorMessage = nil; defer { isBusy = false }
        do { try await backend.requestVerificationCode(phone: phone); return true }
        catch { errorMessage = error.localizedDescription; return false }
    }

    public func signOut() {
        backend.signOut()
        friendsStreamTask?.cancel(); friendsStreamTask = nil
        currentUser = nil; friends = []; conversations = []; places = []
        isAuthenticated = false
    }

    // MARK: - Bootstrap
    public func bootstrap() async {
        do {
            async let f = backend.fetchFriends()
            async let c = backend.fetchConversations()
            async let p = backend.fetchPlaces()
            friends = try await f; conversations = try await c; places = try await p
        } catch { errorMessage = error.localizedDescription }
        subscribeFriends()
    }

    /// 重新拉取好友列表；失败写入 `loadError` 供视图层展示错误态，成功清空之。
    public func reloadFriends() async {
        isBusy = true; loadError = nil; defer { isBusy = false }
        do { friends = try await backend.fetchFriends() }
        catch { loadError = error.localizedDescription }
    }

    private func subscribeFriends() {
        friendsStreamTask?.cancel()
        friendsStreamTask = Task { [weak self] in
            guard let self else { return }
            for await updated in self.backend.friendsStream() { self.friends = updated }
        }
    }

    // MARK: - Friends
    public func addFriend(code: String) async -> Bool {
        isBusy = true; errorMessage = nil; defer { isBusy = false }
        do { _ = try await backend.addFriend(inviteCode: code); return true }
        catch { errorMessage = error.localizedDescription; return false }
    }

    public func toggleFavorite(_ friend: Friend) async {
        do { try await backend.setFavorite(friendId: friend.id, isFavorite: !friend.isFavorite) }
        catch { errorMessage = error.localizedDescription }
    }

    public func removeFriend(_ friend: Friend) async {
        do { try await backend.removeFriend(id: friend.id) }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Safety
    /// 一键求助：把带坐标的 SOS 广播给所有好友。成功返回 true。
    public func sendSOS(at coordinate: Coordinate, note: String = "我需要帮助，请尽快联系我！") async -> Bool {
        do {
            try await backend.sendSOS(coordinate, note: note)
            // 刷新会话列表，让消息 Tab 立即反映 SOS 记录
            if let updated = try? await backend.fetchConversations() { conversations = updated }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Profile
    public func updateProfile(_ profile: UserProfile) async {
        do { try await backend.updateProfile(profile); currentUser = profile }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Diary
    /// AI 轨迹日记：让后端把近期轨迹摘要成一段可分享的故事。
    public func generateTrajectoryDiary() async -> TrajectoryDiary? {
        do { return try await backend.generateTrajectoryDiary() }
        catch { errorMessage = error.localizedDescription; return nil }
    }

    // MARK: - City Pulse
    /// 城市脉搏：附近的人 + 同城活动（泛社交发现流）。
    public func generateCityPulse() async -> CityPulse? {
        do { return try await backend.generateCityPulse() }
        catch { errorMessage = error.localizedDescription; return nil }
    }

    /// 设置城市脉搏可见性（隐私总开关），并同步到本地状态。
    public func setCityPulseVisibility(_ visibility: CityPulseVisibility) async {
        do {
            try await backend.setCityPulseVisibility(visibility)
            cityPulseVisibility = visibility
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Intimate
    /// 亲密关系：加载当前绑定的密友 / 情侣关系（已加载则跳过）。
    @discardableResult
    public func loadIntimateRelation() async -> IntimateRelation? {
        if let existing = intimateRelation { return existing }
        do { intimateRelation = try await backend.fetchIntimateRelation() }
        catch { errorMessage = error.localizedDescription }
        return intimateRelation
    }

    // MARK: - Membership
    /// 会员：加载当前用户的订阅状态（是否会员）。
    public func loadMembershipStatus() async {
        do { isMember = try await backend.fetchMembershipStatus() }
        catch { errorMessage = error.localizedDescription }
    }

    /// 会员：开通订阅。成功返回 true 并把本地状态置为已开通。
    public func subscribeMembership(planId: String) async -> Bool {
        isBusy = true; errorMessage = nil; defer { isBusy = false }
        do {
            try await backend.subscribeMembership(planId: planId)
            isMember = true
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Helpers
    public func friend(by id: String) -> Friend? { friends.first { $0.id == id } }

    public func conversation(forFriend friendId: String) -> Conversation? {
        conversations.first { $0.friendId == friendId }
    }

    public func ensureConversation(for friend: Friend) -> Conversation {
        if let existing = conversation(forFriend: friend.id) { return existing }
        let pairId = [currentUser?.id ?? "me", friend.id].sorted().joined(separator: "_")
        let convo = Conversation(id: pairId, friendId: friend.id, friendName: friend.displayName,
                                 friendAvatar: friend.avatar, lastMessagePreview: "",
                                 lastMessageDate: Date(), unreadCount: 0)
        conversations.append(convo)
        return convo
    }

    public var totalUnread: Int { conversations.reduce(0) { $0 + $1.unreadCount } }
    public var favoriteFriends: [Friend] { friends.filter { $0.isFavorite } }
}
