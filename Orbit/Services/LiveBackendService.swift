import Foundation
import OrbitCore

/// 真实后端实现的骨架（占位）。
///
/// 这是"预留真实后端接口"的落地示例：当你有了真实服务器，把
/// `AppEnvironment.makeBackend()` 改成返回 `LiveBackendService(baseURL:)`
/// 即可，UI 层完全不用改。下面每个方法都标注了对应的 HTTP / 实时通道接入点。
///
/// 目前所有方法抛出 `.notImplemented`，方便在未配置后端时给出明确提示。
@MainActor
final class LiveBackendService: BackendService {

    private let baseURL: URL
    private let session: URLSession
    private var authToken: String?
    private var cachedUser: UserProfile?

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - 鉴权
    func signIn(phone: String, code: String) async throws -> UserProfile {
        // POST \(baseURL)/auth/verify  body: { phone, code }  -> { token, profile }
        // self.authToken = resp.token; self.cachedUser = resp.profile; return resp.profile
        throw BackendError.notImplemented("signIn")
    }

    func currentUser() -> UserProfile? { cachedUser }

    func signOut() { authToken = nil; cachedUser = nil }

    func updateProfile(_ profile: UserProfile) async throws {
        // PUT \(baseURL)/me  body: profile
        throw BackendError.notImplemented("updateProfile")
    }

    // MARK: - 好友
    func fetchFriends() async throws -> [Friend] {
        // GET \(baseURL)/friends
        throw BackendError.notImplemented("fetchFriends")
    }

    func friendsStream() -> AsyncStream<[Friend]> {
        // 真实实现：建立 WebSocket /ws/friends，把每帧解码为 [Friend] 后 yield。
        // 例：
        // AsyncStream { continuation in
        //     let socket = session.webSocketTask(with: wsURL)
        //     socket.resume()
        //     receiveLoop(socket, continuation)
        //     continuation.onTermination = { _ in socket.cancel() }
        // }
        AsyncStream { $0.finish() }
    }

    func addFriend(inviteCode: String) async throws -> Friend {
        // POST \(baseURL)/friends  body: { inviteCode }
        throw BackendError.notImplemented("addFriend")
    }

    func removeFriend(id: String) async throws {
        // DELETE \(baseURL)/friends/\(id)
        throw BackendError.notImplemented("removeFriend")
    }

    func setFavorite(friendId: String, isFavorite: Bool) async throws {
        // PATCH \(baseURL)/friends/\(friendId)  body: { isFavorite }
        throw BackendError.notImplemented("setFavorite")
    }

    func setGhostMode(_ on: Bool) async throws {
        // PATCH \(baseURL)/me/privacy  body: { ghost: on }
        throw BackendError.notImplemented("setGhostMode")
    }

    // MARK: - 位置上报
    func updateMyLocation(_ coordinate: Coordinate) async throws {
        // PUT \(baseURL)/me/location  body: coordinate（建议节流，如 10s 一次）
        throw BackendError.notImplemented("updateMyLocation")
    }

    // MARK: - 聊天
    func fetchConversations() async throws -> [Conversation] {
        // GET \(baseURL)/conversations
        throw BackendError.notImplemented("fetchConversations")
    }

    func messagesStream(conversationId: String) -> AsyncStream<[Message]> {
        // 真实实现：WebSocket /ws/conversations/\(conversationId)
        AsyncStream { $0.finish() }
    }

    func sendMessage(_ kind: Message.Kind, to conversationId: String) async throws -> Message {
        // POST \(baseURL)/conversations/\(conversationId)/messages
        throw BackendError.notImplemented("sendMessage")
    }

    func markRead(conversationId: String) async throws {
        // POST \(baseURL)/conversations/\(conversationId)/read
        throw BackendError.notImplemented("markRead")
    }

    // MARK: - 足迹
    func fetchPlaces() async throws -> [Place] {
        // GET \(baseURL)/places
        throw BackendError.notImplemented("fetchPlaces")
    }
}
