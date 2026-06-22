import Foundation
import SwiftUI
import OrbitCore

@MainActor
public final class SessionStore: ObservableObject {

    @Published public var currentUser: UserProfile?
    @Published public var friends: [Friend] = []
    @Published public var conversations: [Conversation] = []
    @Published public var places: [Place] = []
    @Published public var isAuthenticated = false
    @Published public var isBusy = false
    @Published public var errorMessage: String?

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

    // MARK: - Profile
    public func updateProfile(_ profile: UserProfile) async {
        do { try await backend.updateProfile(profile); currentUser = profile }
        catch { errorMessage = error.localizedDescription }
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
