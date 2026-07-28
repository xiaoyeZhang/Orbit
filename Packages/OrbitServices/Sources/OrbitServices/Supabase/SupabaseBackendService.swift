import Foundation
import OrbitCore

@MainActor
public final class SupabaseBackendService: BackendService {

    private let client    = SupabaseClient.shared
    private let realtime  = SupabaseRealtime.shared
    private var profile:  UserProfile?

    // Realtime subscription IDs
    private var locationSubId: UUID?
    private var messageSubIds: [String: UUID] = [:]

    // AsyncStream continuations
    private var friendsContinuations:  [UUID: AsyncStream<[Friend]>.Continuation] = [:]
    private var messageContinuations:  [String: AsyncStream<[Message]>.Continuation] = [:]

    public init() {
        if client.isSignedIn {
            Task { try? await loadProfile() }
            realtime.connect()
        }
    }

    // MARK: - Auth

    public func requestVerificationCode(phone: String) async throws {
        try await client.sendOTP(phone: phone)
    }

    public func signIn(phone: String, code: String) async throws -> UserProfile {
        let (access, refresh, uid) = try await client.verifyOTP(phone: phone, code: code)
        client.setSession(access: access, refresh: refresh, userId: uid)
        realtime.connect()
        let p = try await loadProfile()
        return p
    }

    public func currentUser() -> UserProfile? { profile }

    public func signOut() {
        client.clearSession()
        realtime.disconnect()
        profile = nil
        friendsContinuations.values.forEach { $0.finish() }
        friendsContinuations = [:]
        messageContinuations.values.forEach { $0.finish() }
        messageContinuations = [:]
    }

    public func updateProfile(_ updated: UserProfile) async throws {
        guard let uid = client.userId else { throw BackendError.notAuthenticated }
        try await client.patch("profiles",
            query: ["id": "eq.\(uid)"],
            body: [
                "display_name": updated.displayName,
                "bio": updated.bio ?? "",
                "avatar_json": encodeAvatar(updated.avatar),
            ])
        profile = updated
    }

    // MARK: - Friends

    public func fetchFriends() async throws -> [Friend] {
        guard let uid = client.userId else { throw BackendError.notAuthenticated }

        // JOIN friendships → profiles → locations
        let rows = try await client.get("friendships", query: [
            "user_id": "eq.\(uid)",
            "select":  "friend_id,is_favorite,is_ghost,profiles!friend_id(id,display_name,avatar_json,invite_code),locations(latitude,longitude,location_name,battery_level,is_charging,movement,speed_kmh,updated_at)",
        ])
        return rows.compactMap { decodeFriend($0) }
    }

    public func friendsStream() -> AsyncStream<[Friend]> {
        AsyncStream { [weak self] continuation in
            guard let self else { continuation.finish(); return }
            let key = UUID()
            self.friendsContinuations[key] = continuation
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor [weak self] in
                    self?.friendsContinuations[key] = nil
                }
            }
            // 初始推送
            Task { [weak self] in
                guard let self else { return }
                if let friends = try? await self.fetchFriends() {
                    continuation.yield(friends)
                }
            }
            // 订阅位置变化
            if self.locationSubId == nil, let uid = self.client.userId {
                self.locationSubId = self.realtime.subscribe(
                    table: "locations",
                    filter: nil
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if let friends = try? await self.fetchFriends() {
                            self.friendsContinuations.values.forEach { $0.yield(friends) }
                        }
                    }
                }
                _ = uid
            }
        }
    }

    public func addFriend(inviteCode: String) async throws -> Friend {
        guard let uid = client.userId else { throw BackendError.notAuthenticated }
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // 找到邀请码对应的用户
        let results = try await client.get("profiles", query: ["invite_code": "eq.\(code)", "select": "id"])
        guard let friendRow = results.first, let friendId = friendRow["id"] as? String
        else { throw BackendError.invalidCode }

        // 创建双向好友关系
        try await client.post("friendships", body: ["user_id": uid, "friend_id": friendId])
        try await client.post("friendships", body: ["user_id": friendId, "friend_id": uid])

        // 返回好友对象
        let friends = try await fetchFriends()
        guard let friend = friends.first(where: { $0.id == friendId })
        else { throw BackendError.friendNotFound }
        return friend
    }

    public func removeFriend(id: String) async throws {
        guard let uid = client.userId else { throw BackendError.notAuthenticated }
        try await client.delete("friendships", query: ["user_id": "eq.\(uid)", "friend_id": "eq.\(id)"])
        try await client.delete("friendships", query: ["user_id": "eq.\(id)", "friend_id": "eq.\(uid)"])
    }

    public func setFavorite(friendId: String, isFavorite: Bool) async throws {
        guard let uid = client.userId else { throw BackendError.notAuthenticated }
        try await client.patch("friendships",
            query: ["user_id": "eq.\(uid)", "friend_id": "eq.\(friendId)"],
            body:  ["is_favorite": isFavorite])
    }

    public func setGhostMode(_ on: Bool) async throws {
        guard let uid = client.userId else { throw BackendError.notAuthenticated }
        try await client.patch("friendships",
            query: ["user_id": "eq.\(uid)"],
            body:  ["is_ghost": on])
    }

    // MARK: - Location / Presence

    public func updateMyLocation(_ coordinate: Coordinate) async throws {
        guard let uid = client.userId else { throw BackendError.notAuthenticated }
        try await client.upsert("locations", body: [
            "user_id":   uid,
            "latitude":  coordinate.latitude,
            "longitude": coordinate.longitude,
            "updated_at": ISO8601DateFormatter().string(from: Date()),
        ])
    }

    public func updatePresence(_ presence: PresenceState) async throws {
        guard let uid = client.userId else { throw BackendError.notAuthenticated }
        try await client.upsert("locations", body: [
            "user_id":       uid,
            "battery_level": presence.batteryLevel,
            "is_charging":   presence.isCharging,
            "movement":      presence.movement.rawValue,
            "speed_kmh":     presence.speedKmh,
            "updated_at":    ISO8601DateFormatter().string(from: Date()),
        ])
    }

    // MARK: - Chat

    public func fetchConversations() async throws -> [Conversation] {
        guard let uid = client.userId else { throw BackendError.notAuthenticated }
        let rows = try await client.get("conversations", query: [
            "or":    "(user1_id.eq.\(uid),user2_id.eq.\(uid))",
            "order": "last_message_at.desc",
            "select": "id,user1_id,user2_id,last_message,last_message_at,unread_count_1,unread_count_2,profiles!user1_id(display_name,avatar_json),profiles!user2_id(display_name,avatar_json)",
        ])
        return rows.compactMap { decodeConversation($0, myId: uid) }
    }

    public func messagesStream(conversationId: String) -> AsyncStream<[Message]> {
        AsyncStream { [weak self] continuation in
            guard let self else { continuation.finish(); return }
            self.messageContinuations[conversationId] = continuation
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor [weak self] in
                    self?.messageContinuations[conversationId] = nil
                }
            }
            Task { [weak self] in
                guard let self else { return }
                if let msgs = try? await self.fetchMessages(conversationId: conversationId) {
                    continuation.yield(msgs)
                }
            }
            // 订阅新消息
            if self.messageSubIds[conversationId] == nil {
                let subId = self.realtime.subscribe(
                    table: "messages",
                    filter: "conversation_id=eq.\(conversationId)"
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if let msgs = try? await self.fetchMessages(conversationId: conversationId) {
                            self.messageContinuations[conversationId]?.yield(msgs)
                        }
                    }
                }
                self.messageSubIds[conversationId] = subId
            }
        }
    }

    public func sendMessage(_ kind: Message.Kind, to conversationId: String) async throws -> Message {
        guard let uid = client.userId else { throw BackendError.notAuthenticated }
        let (kindStr, content) = encodeMessageKind(kind)
        let row = try await client.post("messages", body: [
            "conversation_id": conversationId,
            "sender_id":       uid,
            "kind":            kindStr,
            "content":         content,
        ])
        // Update conversation preview
        let preview = previewText(kind)
        try await client.patch("conversations",
            query: ["id": "eq.\(conversationId)"],
            body:  ["last_message": preview, "last_message_at": ISO8601DateFormatter().string(from: Date())])
        return decodeMessage(row, myId: uid) ?? Message(
            id: row["id"] as? String ?? UUID().uuidString,
            conversationId: conversationId, senderId: uid,
            kind: kind, date: Date(), isRead: true)
    }

    public func markRead(conversationId: String) async throws {
        guard let uid = client.userId else { throw BackendError.notAuthenticated }
        // Determine which column to reset
        let rows = try await client.get("conversations", query: ["id": "eq.\(conversationId)"])
        guard let row = rows.first else { return }
        let user1 = row["user1_id"] as? String
        let col   = user1 == uid ? "unread_count_1" : "unread_count_2"
        try await client.patch("conversations", query: ["id": "eq.\(conversationId)"], body: [col: 0])
    }

    public func fetchPlaces() async throws -> [Place] {
        // Places 暂时返回空（需要另外建表或用 foursquare API）
        return []
    }

    // MARK: - Private Helpers

    @discardableResult
    private func loadProfile() async throws -> UserProfile {
        guard let uid = client.userId else { throw BackendError.notAuthenticated }
        let rows = try await client.get("profiles", query: ["id": "eq.\(uid)"])
        guard let row = rows.first else { throw BackendError.notAuthenticated }
        let p = decodeProfile(row, id: uid)
        profile = p
        return p
    }

    private func fetchMessages(conversationId: String) async throws -> [Message] {
        guard let uid = client.userId else { throw BackendError.notAuthenticated }
        let rows = try await client.get("messages", query: [
            "conversation_id": "eq.\(conversationId)",
            "order": "created_at.asc",
        ])
        return rows.compactMap { decodeMessage($0, myId: uid) }
    }

    // MARK: - Decoders

    private func decodeProfile(_ row: [String: Any], id: String) -> UserProfile {
        UserProfile(
            id:          id,
            displayName: row["display_name"] as? String ?? "",
            bio:         row["bio"] as? String ?? "",
            avatar:      decodeAvatar(row["avatar_json"]),
            inviteCode:  row["invite_code"] as? String ?? ""
        )
    }

    private func decodeFriend(_ row: [String: Any]) -> Friend? {
        guard
            let profileRow = row["profiles"]  as? [String: Any],
            let friendId   = profileRow["id"] as? String
        else { return nil }

        let locRow = row["locations"] as? [String: Any]

        let coord = Coordinate(
            latitude:  locRow?["latitude"]  as? Double ?? 39.9042,
            longitude: locRow?["longitude"] as? Double ?? 116.4074
        )
        let movement = MovementState(rawValue: locRow?["movement"] as? String ?? "") ?? .stationary
        let presence = PresenceState(
            batteryLevel: locRow?["battery_level"] as? Int ?? 100,
            isCharging:   locRow?["is_charging"]   as? Bool ?? false,
            movement:     movement,
            speedKmh:     locRow?["speed_kmh"]     as? Double ?? 0
        )
        let updatedAt: Date = {
            guard let str = locRow?["updated_at"] as? String else { return Date() }
            return ISO8601DateFormatter().date(from: str) ?? Date()
        }()
        return Friend(
            id:           friendId,
            displayName:  profileRow["display_name"] as? String ?? "",
            avatar:       decodeAvatar(profileRow["avatar_json"]),
            coordinate:   coord,
            presence:     presence,
            locationName: locRow?["location_name"] as? String ?? "",
            lastUpdated:  updatedAt,
            isFavorite:   row["is_favorite"] as? Bool ?? false,
            isGhostMode:  row["is_ghost"]    as? Bool ?? false
        )
    }

    private func decodeConversation(_ row: [String: Any], myId: String) -> Conversation? {
        guard let id = row["id"] as? String else { return nil }
        let user1 = row["user1_id"] as? String ?? ""
        let user2 = row["user2_id"] as? String ?? ""
        let isUser1 = user1 == myId
        let friendId = isUser1 ? user2 : user1

        let friendProfile = (isUser1 ? row["profiles!user2_id"] : row["profiles!user1_id"]) as? [String: Any]
        let unread = isUser1
            ? (row["unread_count_1"] as? Int ?? 0)
            : (row["unread_count_2"] as? Int ?? 0)
        let lastAt: Date = {
            guard let s = row["last_message_at"] as? String else { return Date() }
            return ISO8601DateFormatter().date(from: s) ?? Date()
        }()
        return Conversation(
            id:                  id,
            friendId:            friendId,
            friendName:          friendProfile?["display_name"] as? String ?? "",
            friendAvatar:        decodeAvatar(friendProfile?["avatar_json"]),
            lastMessagePreview:  row["last_message"] as? String ?? "",
            lastMessageDate:     lastAt,
            unreadCount:         unread
        )
    }

    private func decodeMessage(_ row: [String: Any], myId: String) -> Message? {
        guard
            let id             = row["id"]              as? String,
            let conversationId = row["conversation_id"] as? String,
            let senderId       = row["sender_id"]       as? String,
            let kindStr        = row["kind"]            as? String,
            let content        = row["content"]         as? [String: Any]
        else { return nil }

        let kind: Message.Kind
        switch kindStr {
        case "location":
            let lat = content["lat"] as? Double ?? 0
            let lng = content["lng"] as? Double ?? 0
            kind = .location(Coordinate(latitude: lat, longitude: lng), name: content["name"] as? String ?? "")
        case "ping":
            kind = .ping
        case "sos":
            let lat = content["lat"] as? Double ?? 0
            let lng = content["lng"] as? Double ?? 0
            kind = .sos(Coordinate(latitude: lat, longitude: lng), note: content["note"] as? String ?? "")
        case "burst":
            kind = .burst(content["emoji"] as? String ?? "🎉")
        default:
            kind = .text(content["text"] as? String ?? "")
        }
        let date: Date = {
            guard let s = row["created_at"] as? String else { return Date() }
            return ISO8601DateFormatter().date(from: s) ?? Date()
        }()
        return Message(id: id, conversationId: conversationId, senderId: senderId,
                       kind: kind, date: date, isRead: row["is_read"] as? Bool ?? false)
    }

    // MARK: - Encoders

    private func encodeAvatar(_ avatar: AvatarConfig) -> [String: Any] {
        [
            "skin":       avatar.skinTone.rawValue,
            "hair":       avatar.hair.rawValue,
            "hairColor":  avatar.hairColor.rawValue,
            "accessory":  avatar.accessory.rawValue,
            "background": avatar.background.rawValue,
        ]
    }

    private func decodeAvatar(_ raw: Any?) -> AvatarConfig {
        guard let dict = raw as? [String: Any] else { return .default }
        return AvatarConfig(
            skinTone:   AvatarConfig.SkinTone(rawValue:       dict["skin"]       as? String ?? "") ?? .medium,
            hair:       AvatarConfig.HairStyle(rawValue:      dict["hair"]       as? String ?? "") ?? .short,
            hairColor:  AvatarConfig.HairColor(rawValue:      dict["hairColor"]  as? String ?? "") ?? .brown,
            accessory:  AvatarConfig.Accessory(rawValue:      dict["accessory"]  as? String ?? "") ?? .none,
            background: AvatarConfig.BackgroundStyle(rawValue: dict["background"] as? String ?? "") ?? .sky
        )
    }

    private func encodeMessageKind(_ kind: Message.Kind) -> (String, [String: Any]) {
        switch kind {
        case .text(let t):              return ("text",     ["text": t])
        case .location(let c, let n):   return ("location", ["lat": c.latitude, "lng": c.longitude, "name": n])
        case .ping:                     return ("ping",     [:])
        case .sos(let c, let note):     return ("sos",      ["lat": c.latitude, "lng": c.longitude, "note": note])
        case .burst(let emoji):         return ("burst",    ["emoji": emoji])
        }
    }

    private func previewText(_ kind: Message.Kind) -> String {
        switch kind {
        case .text(let t):        return t
        case .location(_, let n): return "📍 \(n.isEmpty ? "位置" : n)"
        case .ping:               return "👋 Ping"
        case .sos(_, let note):   return "🆘 \(note)"
        case .burst(let emoji):   return "\(emoji) 轰炸"
        }
    }
}
