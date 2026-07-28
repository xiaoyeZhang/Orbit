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

    // MARK: Safety
    /// 一键求助：把带当前坐标的 SOS 消息广播给所有好友。
    func sendSOS(_ coordinate: Coordinate, note: String) async throws

    // MARK: Diary
    /// AI 轨迹日记：把一段时间内的轨迹摘要成一段可分享的「故事」。
    func generateTrajectoryDiary() async throws -> TrajectoryDiary

    // MARK: City Pulse
    /// 城市脉搏：附近的人 + 同城活动（泛社交发现流）。
    func generateCityPulse() async throws -> CityPulse
    /// 设置城市脉搏的可见性（隐私总开关）。
    func setCityPulseVisibility(_ visibility: CityPulseVisibility) async throws

    // MARK: Intimate
    /// 亲密关系：返回当前用户绑定的密友 / 情侣关系；未绑定返回 nil。
    func fetchIntimateRelation() async throws -> IntimateRelation?

    // MARK: Membership
    /// 会员：查询当前用户的订阅状态（是否会员）。
    func fetchMembershipStatus() async throws -> Bool
    /// 会员：开通订阅（planId 例如 "single"）。
    func subscribeMembership(planId: String) async throws

    // MARK: Places
    func fetchPlaces() async throws -> [Place]
}

extension BackendService {
    public func requestVerificationCode(phone: String) async throws {}
    public func updatePresence(_ presence: PresenceState) async throws {}
    public func sendSOS(_ coordinate: Coordinate, note: String) async throws {}
    public func generateTrajectoryDiary() async throws -> TrajectoryDiary { TrajectoryDiary.sample }
    public func generateCityPulse() async throws -> CityPulse { CityPulse.sample }
    public func setCityPulseVisibility(_ visibility: CityPulseVisibility) async throws {}
    public func fetchIntimateRelation() async throws -> IntimateRelation? { nil }
    public func fetchMembershipStatus() async throws -> Bool { false }
    public func subscribeMembership(planId: String) async throws {}
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
