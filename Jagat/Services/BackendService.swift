import Foundation

/// 后端服务契约。
///
/// 这是「预留真实后端接口」的核心：UI 层只依赖该协议，不关心数据来自
/// 本地 Mock 还是真实服务器。要接入真实后端时，只需新增一个实现
/// （见 `LiveBackendService`），把 `AppEnvironment.backend` 换掉即可，
/// 业务代码无需改动。
///
/// - 鉴权用 async/await。
/// - 实时数据（好友位置、聊天消息）用 `AsyncStream` 推送，
///   对应真实实现里的 WebSocket / SSE / Firebase 监听。
/// - 协议标注 `@MainActor`：所有实现与调用都在主线程，SwiftUI 状态更新无需切换线程、天然无数据竞争。
@MainActor
protocol BackendService: AnyObject {

    // MARK: 鉴权
    /// 请求短信验证码（真实实现 = Firebase PhoneAuth 发送 SMS 并记下 verificationID）。
    func requestVerificationCode(phone: String) async throws
    func signIn(phone: String, code: String) async throws -> UserProfile
    func currentUser() -> UserProfile?
    func signOut()
    func updateProfile(_ profile: UserProfile) async throws

    // MARK: 好友
    func fetchFriends() async throws -> [Friend]
    /// 实时好友位置流。真实实现 = 服务端推送；Mock = 定时器模拟移动。
    func friendsStream() -> AsyncStream<[Friend]>
    func addFriend(inviteCode: String) async throws -> Friend
    func removeFriend(id: String) async throws
    func setFavorite(friendId: String, isFavorite: Bool) async throws
    func setGhostMode(_ on: Bool) async throws

    // MARK: 位置上报
    func updateMyLocation(_ coordinate: Coordinate) async throws
    /// 上报我的状态（电量 / 充电 / 移动 / 速度）。真实实现写入 users/{me}.presence。
    func updatePresence(_ presence: PresenceState) async throws

    // MARK: 聊天
    func fetchConversations() async throws -> [Conversation]
    func messagesStream(conversationId: String) -> AsyncStream<[Message]>
    func sendMessage(_ kind: Message.Kind, to conversationId: String) async throws -> Message
    func markRead(conversationId: String) async throws

    // MARK: 足迹
    func fetchPlaces() async throws -> [Place]
}

extension BackendService {
    /// 默认空实现：Mock / REST 桩无需独立的「发送验证码」步骤即可继续登录流程。
    func requestVerificationCode(phone: String) async throws {}
    /// 默认空实现：未对接状态上报的后端忽略它。
    func updatePresence(_ presence: PresenceState) async throws {}
}

/// 后端层错误。
enum BackendError: LocalizedError {
    case notAuthenticated
    case invalidCode
    case friendNotFound
    case notImplemented(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "请先登录"
        case .invalidCode: return "验证码 / 邀请码无效"
        case .friendNotFound: return "未找到该好友"
        case .notImplemented(let what): return "尚未接入真实后端：\(what)"
        case .network(let msg): return "网络错误：\(msg)"
        }
    }
}
