import Foundation

/// 后端协议的本地 Mock 实现。
///
/// - 内置一批示例好友 / 会话 / 足迹数据，App 无需联网即可完整运行。
/// - `friendsStream()` 用结构化任务 + `Task.sleep` 定时微调好友坐标 / 移动状态，
///   模拟"实时位置推送"，让地图上的好友会缓慢移动。
/// - `sendMessage()` 会在片刻后自动生成一条好友回复，便于演示聊天。
@MainActor
final class MockBackendService: BackendService {

    // MARK: 内存状态
    private var user: UserProfile?
    private var friends: [Friend] = SampleData.friends
    private var conversations: [Conversation] = SampleData.conversations
    private var messagesByConversation: [String: [Message]] = SampleData.messages
    private let places: [Place] = SampleData.places

    // 实时流的续延（continuation），用于在数据变化时主动推送。
    private var friendsContinuations: [UUID: AsyncStream<[Friend]>.Continuation] = [:]
    private var messageContinuations: [String: AsyncStream<[Message]>.Continuation] = [:]

    private var movementTask: Task<Void, Never>?

    init() {
        startMovementSimulation()
    }

    // MARK: - 鉴权
    func signIn(phone: String, code: String) async throws -> UserProfile {
        try await Task.sleep(nanoseconds: 600_000_000)  // 模拟网络延迟
        guard code.count >= 4 else { throw BackendError.invalidCode }
        let profile = UserProfile(
            id: "me",
            displayName: "我",
            bio: "在路上 🚀",
            avatar: AvatarConfig(skinTone: .medium, hair: .short, hairColor: .brown, accessory: .glasses, background: .violet),
            inviteCode: "JAGAT-ME01",
            phoneNumber: phone
        )
        user = profile
        return profile
    }

    func currentUser() -> UserProfile? { user }

    func signOut() { user = nil }

    func updateProfile(_ profile: UserProfile) async throws {
        guard user != nil else { throw BackendError.notAuthenticated }
        user = profile
    }

    // MARK: - 好友
    func fetchFriends() async throws -> [Friend] {
        try await Task.sleep(nanoseconds: 300_000_000)
        return friends
    }

    func friendsStream() -> AsyncStream<[Friend]> {
        AsyncStream { continuation in
            let key = UUID()
            friendsContinuations[key] = continuation
            continuation.yield(friends)           // 立即推送当前快照
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor [weak self] in self?.friendsContinuations[key] = nil }
            }
        }
    }

    func addFriend(inviteCode: String) async throws -> Friend {
        try await Task.sleep(nanoseconds: 500_000_000)
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.count >= 4 else { throw BackendError.invalidCode }
        // Mock：邀请码生成一位新好友落在自己附近。
        let base = friends.first?.coordinate ?? SampleData.cityCenter
        let newFriend = Friend(
            id: UUID().uuidString,
            displayName: SampleData.randomName(),
            avatar: SampleData.randomAvatar(),
            coordinate: Coordinate(latitude: base.latitude + .random(in: -0.01...0.01),
                                   longitude: base.longitude + .random(in: -0.01...0.01)),
            presence: PresenceState(batteryLevel: .random(in: 30...100), isCharging: false,
                                    movement: .stationary, speedKmh: 0),
            locationName: "刚刚通过邀请码添加",
            lastUpdated: Date(),
            isFavorite: false,
            isGhostMode: false
        )
        friends.append(newFriend)
        broadcastFriends()
        return newFriend
    }

    func removeFriend(id: String) async throws {
        friends.removeAll { $0.id == id }
        broadcastFriends()
    }

    func setFavorite(friendId: String, isFavorite: Bool) async throws {
        guard let idx = friends.firstIndex(where: { $0.id == friendId }) else { throw BackendError.friendNotFound }
        friends[idx].isFavorite = isFavorite
        broadcastFriends()
    }

    func setGhostMode(_ on: Bool) async throws {
        // Mock：把第一位好友设为隐身用于演示。真实实现应作用于当前用户。
    }

    // MARK: - 位置上报
    func updateMyLocation(_ coordinate: Coordinate) async throws {
        // Mock：真实实现会把坐标 PUT 给服务器并广播给好友。
    }

    // MARK: - 聊天
    func fetchConversations() async throws -> [Conversation] {
        try await Task.sleep(nanoseconds: 250_000_000)
        return conversations.sorted { $0.lastMessageDate > $1.lastMessageDate }
    }

    func messagesStream(conversationId: String) -> AsyncStream<[Message]> {
        AsyncStream { continuation in
            messageContinuations[conversationId] = continuation
            continuation.yield(messagesByConversation[conversationId] ?? [])
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor [weak self] in self?.messageContinuations[conversationId] = nil }
            }
        }
    }

    func sendMessage(_ kind: Message.Kind, to conversationId: String) async throws -> Message {
        let message = Message(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: "me",
            kind: kind,
            date: Date(),
            isRead: true
        )
        appendMessage(message, to: conversationId)
        scheduleAutoReply(to: conversationId)
        return message
    }

    func markRead(conversationId: String) async throws {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        conversations[idx].unreadCount = 0
    }

    // MARK: - 足迹
    func fetchPlaces() async throws -> [Place] {
        try await Task.sleep(nanoseconds: 200_000_000)
        return places.sorted { $0.lastVisit > $1.lastVisit }
    }

    // MARK: - 私有：广播与模拟
    private func broadcastFriends() {
        for c in friendsContinuations.values { c.yield(friends) }
    }

    private func appendMessage(_ message: Message, to conversationId: String) {
        messagesByConversation[conversationId, default: []].append(message)
        messageContinuations[conversationId]?.yield(messagesByConversation[conversationId] ?? [])
        if let idx = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[idx].lastMessagePreview = message.preview
            conversations[idx].lastMessageDate = message.date
            if !message.isMine { conversations[idx].unreadCount += 1 }
        }
    }

    private func scheduleAutoReply(to conversationId: String) {
        guard let convo = conversations.first(where: { $0.id == conversationId }) else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard let self else { return }
            let replies = ["收到～", "哈哈哈", "我在路上，马上到", "你那边天气怎么样？", "晚点约个饭？", "📍 我刚到这边"]
            let reply = Message(
                id: UUID().uuidString,
                conversationId: conversationId,
                senderId: convo.friendId,
                kind: .text(replies.randomElement() ?? "在的"),
                date: Date(),
                isRead: false
            )
            self.appendMessage(reply, to: conversationId)
        }
    }

    /// 每 3 秒微调好友坐标 / 移动状态，模拟实时移动。
    private func startMovementSimulation() {
        movementTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard let self else { return }
                self.tickMovement()
                self.broadcastFriends()
            }
        }
    }

    private func tickMovement() {
        for i in friends.indices {
            guard !friends[i].isGhostMode else { continue }
            switch friends[i].presence.movement {
            case .stationary:
                if Double.random(in: 0...1) < 0.2 {
                    friends[i].presence.movement = [.walking, .driving].randomElement()!
                }
            case .walking:
                nudge(&friends[i], meters: 0.00012)
                friends[i].presence.speedKmh = .random(in: 3...6)
                if Double.random(in: 0...1) < 0.3 { friends[i].presence.movement = .stationary; friends[i].presence.speedKmh = 0 }
            case .driving:
                nudge(&friends[i], meters: 0.0006)
                friends[i].presence.speedKmh = .random(in: 25...55)
                if Double.random(in: 0...1) < 0.25 { friends[i].presence.movement = .stationary; friends[i].presence.speedKmh = 0 }
            case .flying:
                nudge(&friends[i], meters: 0.004)
                friends[i].presence.speedKmh = .random(in: 700...900)
            }
            // 电量缓慢波动
            if Double.random(in: 0...1) < 0.15 {
                friends[i].presence.batteryLevel = max(1, min(100, friends[i].presence.batteryLevel + Int.random(in: -2...1)))
            }
            friends[i].lastUpdated = Date()
        }
    }

    private func nudge(_ friend: inout Friend, meters: Double) {
        friend.coordinate.latitude += .random(in: -meters...meters)
        friend.coordinate.longitude += .random(in: -meters...meters)
    }

    deinit { movementTask?.cancel() }
}
