import Foundation

@MainActor
public protocol BackendService: AnyObject {

    // MARK: Auth
    func requestVerificationCode(phone: String) async throws
    func signIn(phone: String, code: String) async throws -> UserProfile
    func currentUser() -> UserProfile?
    func signOut()
    func updateProfile(_ profile: UserProfile) async throws

    // MARK: Friends
    func fetchFriends() async throws -> [Friend]
    func friendsStream() -> AsyncStream<[Friend]>
    func addFriend(inviteCode: String) async throws -> Friend
    func removeFriend(id: String) async throws
    func setFavorite(friendId: String, isFavorite: Bool) async throws
    func setGhostMode(_ on: Bool) async throws

    // MARK: Location
    func updateMyLocation(_ coordinate: Coordinate) async throws
    func updatePresence(_ presence: PresenceState) async throws

    // MARK: Chat
    func fetchConversations() async throws -> [Conversation]
    func messagesStream(conversationId: String) -> AsyncStream<[Message]>
    func sendMessage(_ kind: Message.Kind, to conversationId: String) async throws -> Message
    func markRead(conversationId: String) async throws

    // MARK: Places
    func fetchPlaces() async throws -> [Place]
}

extension BackendService {
    public func requestVerificationCode(phone: String) async throws {}
    public func updatePresence(_ presence: PresenceState) async throws {}
}

public enum BackendError: LocalizedError, Sendable {
    case notAuthenticated
    case invalidCode
    case friendNotFound
    case notImplemented(String)
    case network(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:       return "请先登录"
        case .invalidCode:            return "验证码 / 邀请码无效"
        case .friendNotFound:         return "未找到该好友"
        case .notImplemented(let w):  return "尚未接入真实后端：\(w)"
        case .network(let m):         return "网络错误：\(m)"
        }
    }
}
