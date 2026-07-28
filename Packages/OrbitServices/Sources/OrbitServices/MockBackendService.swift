import Foundation
import OrbitCore

@MainActor
public final class MockBackendService: BackendService {

    private static let userDefaultsKey = "mock_current_user"

    private var user: UserProfile? {
        didSet { persistUser() }
    }
    private var friends: [Friend] = SampleData.friends
    private var conversations: [Conversation] = SampleData.conversations
    private var messagesByConversation: [String: [Message]] = SampleData.messages
    private let places: [Place] = SampleData.places
    private var cityPulseVisibility: CityPulseVisibility = .friendsOnly

    private var friendsContinuations: [UUID: AsyncStream<[Friend]>.Continuation] = [:]
    private var messageContinuations: [String: AsyncStream<[Message]>.Continuation] = [:]
    private var movementTask: Task<Void, Never>?

    public init() {
        // Restore persisted session
        if let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            user = profile
        }
        startMovementSimulation()
    }

    private func persistUser() {
        if let user, let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.userDefaultsKey)
        }
    }

    // MARK: - Auth
    public func signIn(phone: String, code: String) async throws -> UserProfile {
        try await Task.sleep(nanoseconds: 600_000_000)
        guard code.count >= 4 else { throw BackendError.invalidCode }
        let profile = UserProfile(id: "me", displayName: "我", bio: "在路上 🚀",
                                  avatar: AvatarConfig(skinTone: .medium, hair: .short,
                                                       hairColor: .brown, accessory: .glasses, background: .violet),
                                  inviteCode: "ORBIT-ME01", phoneNumber: phone)
        user = profile; return profile
    }
    public func currentUser() -> UserProfile? { user }
    public func signOut() {
        user = nil  // didSet calls persistUser() → removes from UserDefaults
    }
    public func updateProfile(_ profile: UserProfile) async throws {
        guard user != nil else { throw BackendError.notAuthenticated }
        user = profile
    }

    // MARK: - Friends
    public func fetchFriends() async throws -> [Friend] {
        try await Task.sleep(nanoseconds: 300_000_000); return friends
    }
    public func friendsStream() -> AsyncStream<[Friend]> {
        AsyncStream { continuation in
            let key = UUID()
            friendsContinuations[key] = continuation
            continuation.yield(friends)
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor [weak self] in self?.friendsContinuations[key] = nil }
            }
        }
    }
    public func addFriend(inviteCode: String) async throws -> Friend {
        try await Task.sleep(nanoseconds: 500_000_000)
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.count >= 4 else { throw BackendError.invalidCode }
        let base = friends.first?.coordinate ?? SampleData.cityCenter
        let newFriend = Friend(
            id: UUID().uuidString, displayName: SampleData.randomName(),
            avatar: SampleData.randomAvatar(),
            coordinate: Coordinate(latitude: base.latitude + .random(in: -0.01...0.01),
                                   longitude: base.longitude + .random(in: -0.01...0.01)),
            presence: PresenceState(batteryLevel: .random(in: 30...100), isCharging: false,
                                    movement: .stationary, speedKmh: 0),
            locationName: "刚刚通过邀请码添加", lastUpdated: Date(),
            isFavorite: false, isGhostMode: false
        )
        friends.append(newFriend); broadcastFriends(); return newFriend
    }
    public func removeFriend(id: String) async throws {
        friends.removeAll { $0.id == id }; broadcastFriends()
    }
    public func setFavorite(friendId: String, isFavorite: Bool) async throws {
        guard let idx = friends.firstIndex(where: { $0.id == friendId }) else { throw BackendError.friendNotFound }
        friends[idx].isFavorite = isFavorite; broadcastFriends()
    }
    public func setGhostMode(_ on: Bool) async throws {
        // Reflect ghost state on the local user so it stays consistent with the UI
        // and is persisted via `user` didSet → UserDefaults.
        if var u = user { u.isGhostMode = on; user = u }
    }
    public func updateMyLocation(_ coordinate: Coordinate) async throws {}

    // MARK: - Chat
    public func fetchConversations() async throws -> [Conversation] {
        try await Task.sleep(nanoseconds: 250_000_000)
        return conversations.sorted { $0.lastMessageDate > $1.lastMessageDate }
    }
    public func messagesStream(conversationId: String) -> AsyncStream<[Message]> {
        AsyncStream { continuation in
            messageContinuations[conversationId] = continuation
            continuation.yield(messagesByConversation[conversationId] ?? [])
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor [weak self] in self?.messageContinuations[conversationId] = nil }
            }
        }
    }
    public func sendMessage(_ kind: Message.Kind, to conversationId: String) async throws -> Message {
        let message = Message(id: UUID().uuidString, conversationId: conversationId,
                              senderId: "me", kind: kind, date: Date(), isRead: true)
        appendMessage(message, to: conversationId)
        scheduleAutoReply(to: conversationId, inResponseTo: kind)
        return message
    }
    public func markRead(conversationId: String) async throws {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        conversations[idx].unreadCount = 0
    }

    // MARK: - Safety
    public func sendSOS(_ coordinate: Coordinate, note: String) async throws {
        guard user != nil else { throw BackendError.notAuthenticated }
        // 广播给所有好友：已有会话直接发，没有会话的好友自动建会话
        for friend in friends {
            let conversationId: String
            if let convo = conversations.first(where: { $0.friendId == friend.id }) {
                conversationId = convo.id
            } else {
                let convo = Conversation(id: "c-\(friend.id)", friendId: friend.id,
                                         friendName: friend.displayName, friendAvatar: friend.avatar,
                                         lastMessagePreview: "", lastMessageDate: Date(), unreadCount: 0)
                conversations.append(convo)
                conversationId = convo.id
            }
            let message = Message(id: UUID().uuidString, conversationId: conversationId,
                                  senderId: "me",
                                  kind: .sos(coordinate, note: note),
                                  date: Date(), isRead: true)
            appendMessage(message, to: conversationId)
        }
        // 模拟一位好友第一时间回应，让演示更真实
        if let first = conversations.first {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self else { return }
                let reply = Message(id: UUID().uuidString, conversationId: first.id,
                                    senderId: first.friendId,
                                    kind: .text("收到！我马上过来，保持手机畅通 ❤️"),
                                    date: Date(), isRead: false)
                self.appendMessage(reply, to: first.id)
            }
        }
    }
    public func fetchPlaces() async throws -> [Place] {
        try await Task.sleep(nanoseconds: 200_000_000)
        return places.sorted { $0.lastVisit > $1.lastVisit }
    }

    // MARK: - Diary
    public func generateTrajectoryDiary() async throws -> TrajectoryDiary {
        guard user != nil else { throw BackendError.notAuthenticated }
        try await Task.sleep(nanoseconds: 900_000_000)   // 模拟 AI 撰写耗时

        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: Date())
        let weekdayName = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"][weekday - 1]
        let me = SampleData.cityCenter

        // 选 2~3 个最常去的地标作为今日途经点
        let picks = Array(places.shuffled().prefix(Int.random(in: 2...3)))
        var distance = Double.random(in: 2...5)
        var highlights: [DiaryHighlight] = []
        var placeNames: [String] = []
        for (i, p) in picks.enumerated() {
            let dToPrev = (i == 0 ? p.coordinate.distance(to: me) : picks[i - 1].coordinate.distance(to: p.coordinate)) / 1000
            distance += dToPrev
            let hour = Int.random(in: 9...21)
            let time = String(format: "%02d:%02d", hour, Int.random(in: 0...59))
            let note = Self.placeNotes.randomElement()!
            highlights.append(.init(id: "hl-\(p.id)-\(i)", placeName: p.name, emoji: p.emoji, note: note, time: time))
            placeNames.append(p.name)
        }

        let moods = ["惬意", "充实", "松弛", "自在", "温柔", "有点忙"]
        let mood = moods.randomElement()!
        let cover = ["🌇", "🌿", "☀️", "🌙", "🍃", "✨"].randomElement()!

        return TrajectoryDiary(
            id: UUID().uuidString,
            title: "\(weekdayName)的城市漫游",
            date: Date(),
            coverEmoji: cover,
            story: Self.composeStory(weekdayName: weekdayName, places: placeNames, mood: mood),
            highlights: highlights,
            distanceKm: (distance * 10).rounded() / 10,
            durationLabel: "活跃 \(Int.random(in: 6...11)) 小时",
            mood: mood,
            placesVisited: highlights.count
        )
    }

    private static let placeNotes = [
        "待了一会儿，喝了点东西",
        "忙完了一桩正事",
        "顺路拐进来歇了歇脚",
        "见了个朋友，聊得挺开心",
        "在这儿发了会儿呆",
        "傍晚的光线特别好看",
    ]

    private static func composeStory(weekdayName: String, places: [String], mood: String) -> String {
        guard !places.isEmpty else {
            return "\(weekdayName)你大多待在一个地方，安静地过了一天——这种专注本身就很珍贵。"
        }
        let rest = places.dropFirst()
        var s = "\(weekdayName)，你从「\(places[0])」开始了一天"
        if !rest.isEmpty {
            s += "，又路过" + rest.map { "「\($0)」" }.joined(separator: "、")
        }
        s += "。一整天的心情是\(mood)的——轨迹里藏着你自己的生活节奏，平凡却真实。"
        return s
    }

    // MARK: - City Pulse
    public func setCityPulseVisibility(_ visibility: CityPulseVisibility) async throws {
        cityPulseVisibility = visibility
    }

    public func generateCityPulse() async throws -> CityPulse {
        guard user != nil else { throw BackendError.notAuthenticated }
        try await Task.sleep(nanoseconds: 500_000_000)

        // 关闭时返回空内容：既不暴露自己，也看不到别人（隐私端到端生效）
        guard cityPulseVisibility != .off else {
            return CityPulse(id: UUID().uuidString, generatedAt: Date(),
                             visibility: .off, nearby: [], events: [])
        }

        let friendNames = friends.map { $0.displayName }
        let nearbyCount = cityPulseVisibility == .everyone ? Int.random(in: 5...8) : Int.random(in: 3...5)
        let nearby = (0..<nearbyCount).map { i in
            let name = SampleData.randomName()
            let mutual = friendNames.shuffled().prefix(Int.random(in: 1...2)).map { $0 }
            return NearbyPerson(
                id: "np-\(i)-\(UUID().uuidString.prefix(4))",
                displayName: name,
                avatar: SampleData.randomAvatar(),
                distanceKm: round((Double.random(in: 0.3...6)) * 10) / 10,
                mutualFriends: mutual,
                lastSeenText: ["刚刚", "5 分钟前在线", "20 分钟前在线", "1 小时前在线"].randomElement()!
            )
        }

        let templates: [(String, String, String)] = [
            ("鼓楼夜骑", "🚲", "鼓楼大街"),
            ("天台电影夜", "🎬", "国贸某天台"),
            ("周末市集", "🛍️", "798 艺术区"),
            ("江边夜跑", "🌃", "亮马河"),
            ("读书分享会", "📚", "三联书店"),
            ("咖啡品鉴", "☕️", "某独立咖啡馆"),
        ]
        let events = Array(templates.shuffled().prefix(Int.random(in: 2...3))).enumerated().map { (i, t) in
            CityEvent(id: "ev-\(i)", title: t.0, emoji: t.1, placeName: t.2,
                      startsIn: ["今晚 19:30", "今晚 20:00", "明天 14:00", "周六 15:00"].randomElement()!,
                      attendees: Int.random(in: 5...60),
                      category: ["运动", "休闲", "文化", "美食"].randomElement()!)
        }

        return CityPulse(id: UUID().uuidString, generatedAt: Date(),
                         visibility: cityPulseVisibility, nearby: nearby, events: events)
    }

    // MARK: - Intimate
    public func fetchIntimateRelation() async throws -> IntimateRelation? {
        try await Task.sleep(nanoseconds: 300_000_000)
        return IntimateRelation.sample
    }

    // MARK: - Membership
    public func fetchMembershipStatus() async throws -> Bool {
        try await Task.sleep(nanoseconds: 150_000_000)
        return false
    }

    public func subscribeMembership(planId: String) async throws {
        try await Task.sleep(nanoseconds: 800_000_000)
    }

    // MARK: - Private
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
    private func scheduleAutoReply(to conversationId: String, inResponseTo kind: Message.Kind? = nil) {
        guard let convo = conversations.first(where: { $0.id == conversationId }) else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard let self else { return }
            let replyKind: Message.Kind
            switch kind {
            case .burst(let emoji):
                // 收到轰炸：一半几率同款 emoji 轰炸回去，否则文字吐槽
                replyKind = Bool.random()
                    ? .burst(emoji)
                    : .text(["哈哈哈被你炸到了", "接招！", "别闹 😂"].randomElement()!)
            case .ping:
                replyKind = .text(["戳我干嘛 😆", "在的在的", "👀"].randomElement()!)
            default:
                let replies = ["收到～", "哈哈哈", "我在路上，马上到", "你那边天气怎么样？", "晚点约个饭？", "📍 我刚到这边"]
                replyKind = .text(replies.randomElement() ?? "在的")
            }
            let reply = Message(id: UUID().uuidString, conversationId: conversationId,
                                senderId: convo.friendId, kind: replyKind,
                                date: Date(), isRead: false)
            self.appendMessage(reply, to: conversationId)
        }
    }
    private func startMovementSimulation() {
        movementTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard let self else { return }
                self.tickMovement(); self.broadcastFriends()
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
