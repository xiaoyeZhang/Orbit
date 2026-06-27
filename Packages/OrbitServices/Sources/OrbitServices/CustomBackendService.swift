import Foundation
import OrbitCore

// MARK: - Custom HTTP backend (connects to jagat-backend docker service)

@MainActor
public final class CustomBackendService: BackendService {

    private let base: URL
    private var token: String? {
        get { UserDefaults.standard.string(forKey: "custom_token") }
        set { UserDefaults.standard.set(newValue, forKey: "custom_token") }
    }
    private var cachedUser: UserProfile? {
        get {
            guard let d = UserDefaults.standard.data(forKey: "custom_user") else { return nil }
            return try? JSONDecoder().decode(UserProfile.self, from: d)
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: "custom_user") }
    }

    private var sseTask: URLSessionDataTask?
    private var friendContinuations: [UUID: AsyncStream<[Friend]>.Continuation] = [:]
    private var msgContinuations: [String: [UUID: AsyncStream<[Message]>.Continuation]] = [:]
    private var latestFriends: [Friend] = []

    public init(baseURL: String) {
        var url = baseURL
        if url.hasSuffix("/") { url = String(url.dropLast()) }
        self.base = URL(string: url)!
    }

    // MARK: - Auth

    public func requestVerificationCode(phone: String) async throws {
        _ = try await post("/auth/request-code", body: ["phone": phone], auth: false)
    }

    public func signIn(phone: String, code: String) async throws -> UserProfile {
        let res = try await post("/auth/verify", body: ["phone": phone, "code": code], auth: false)
        guard let tok = res["token"] as? String,
              let ud  = res["user"]  as? [String: Any]
        else { throw BackendError.network("Bad response") }
        token = tok
        let profile = decodeUser(ud, phone: phone)
        cachedUser = profile
        return profile
    }

    public func currentUser() -> UserProfile? { cachedUser }
    public func signOut() { token = nil; cachedUser = nil; sseTask?.cancel(); sseTask = nil }

    public func updateProfile(_ profile: UserProfile) async throws {
        var body: [String: Any] = ["displayName": profile.displayName, "bio": profile.bio ?? ""]
        if let av = try? JSONEncoder().encode(profile.avatar),
           let obj = try? JSONSerialization.jsonObject(with: av) { body["avatar"] = obj }
        _ = try await patch("/users/me", body: body)
        cachedUser = profile
    }

    // MARK: - Friends

    public func fetchFriends() async throws -> [Friend] {
        let arr = try await getArray("/friends")
        latestFriends = arr.compactMap(decodeFriend)
        return latestFriends
    }

    public func friendsStream() -> AsyncStream<[Friend]> {
        AsyncStream { continuation in
            let key = UUID()
            friendContinuations[key] = continuation
            continuation.yield(latestFriends)
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor [weak self] in self?.friendContinuations[key] = nil }
            }
            startSSE()
        }
    }

    public func addFriend(inviteCode: String) async throws -> Friend {
        let res = try await post("/friends/add", body: ["inviteCode": inviteCode])
        guard let f = decodeFriend(res) else { throw BackendError.friendNotFound }
        return f
    }

    public func removeFriend(id: String) async throws {
        _ = try await delete("/friends/\(id)")
    }

    public func setFavorite(friendId: String, isFavorite: Bool) async throws {
        _ = try await patch("/friends/\(friendId)/favorite", body: ["isFavorite": isFavorite])
    }

    public func setGhostMode(_ on: Bool) async throws {
        _ = try await patch("/users/me/ghost-mode", body: ["enabled": on])
    }

    // MARK: - Location

    public func updateMyLocation(_ coordinate: Coordinate) async throws {
        let body: [String: Any] = ["latitude": coordinate.latitude, "longitude": coordinate.longitude]
        _ = try await post("/location", body: body)
    }

    public func updatePresence(_ presence: PresenceState) async throws {
        let body: [String: Any] = [
            "battery": presence.batteryLevel,
            "isCharging": presence.isCharging,
            "movement": presence.movement.rawValue,
        ]
        _ = try await patch("/location/presence", body: body)
    }

    // MARK: - Chat

    public func fetchConversations() async throws -> [Conversation] {
        let arr = try await getArray("/conversations")
        return arr.compactMap(decodeConversation)
    }

    public func messagesStream(conversationId: String) -> AsyncStream<[Message]> {
        AsyncStream { continuation in
            let key = UUID()
            msgContinuations[conversationId, default: [:]][key] = continuation
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor [weak self] in self?.msgContinuations[conversationId]?[key] = nil }
            }
            Task { [weak self] in
                guard let self else { return }
                if let msgs = try? await self.fetchMessages(conversationId: conversationId) {
                    continuation.yield(msgs)
                }
            }
        }
    }

    public func sendMessage(_ kind: Message.Kind, to conversationId: String) async throws -> Message {
        let text: String
        switch kind {
        case .text(let t): text = t
        default: throw BackendError.notImplemented("Only text messages supported")
        }
        let res = try await post("/conversations/\(conversationId)/messages", body: ["content": text])
        guard let id = res["id"] as? String else { throw BackendError.network("Bad response") }
        let msg = Message(id: id, conversationId: conversationId,
                          senderId: cachedUser?.id ?? "", kind: kind,
                          date: Date(), isRead: true)
        // Push to stream
        let existing = try? await fetchMessages(conversationId: conversationId)
        if let msgs = existing {
            for cont in msgContinuations[conversationId]?.values ?? [:].values { cont.yield(msgs) }
        }
        return msg
    }

    public func markRead(conversationId: String) async throws {
        _ = try await patch("/conversations/\(conversationId)/read", body: [:])
    }

    // MARK: - Places

    public func fetchPlaces() async throws -> [Place] {
        let arr = try await getArray("/places")
        return arr.compactMap(decodePlace)
    }

    // MARK: - SSE

    private func startSSE() {
        guard sseTask == nil, let tok = token else { return }
        var req = URLRequest(url: base.appendingPathComponent("/friends/stream"))
        req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.timeoutInterval = .infinity
        let task = URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self, let data else { return }
            let text = String(data: data, encoding: .utf8) ?? ""
            for line in text.components(separatedBy: "\n") {
                guard line.hasPrefix("data: "),
                      let d = line.dropFirst(6).data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any]
                else { continue }
                Task { @MainActor in self.handleSSE(obj) }
            }
        }
        task.resume(); sseTask = task
    }

    private func handleSSE(_ obj: [String: Any]) {
        switch obj["type"] as? String {
        case "snapshot":
            if let arr = obj["friends"] as? [[String: Any]] {
                latestFriends = arr.compactMap(decodeFriend)
            }
        case "location_update":
            guard let uid = obj["userId"] as? String,
                  let lat = obj["latitude"] as? Double,
                  let lon = obj["longitude"] as? Double else { return }
            latestFriends = latestFriends.map { f in
                guard f.id == uid else { return f }
                return Friend(
                    id: f.id, displayName: f.displayName, avatar: f.avatar,
                    coordinate: Coordinate(latitude: lat, longitude: lon),
                    presence: PresenceState(
                        batteryLevel: obj["battery"]    as? Int  ?? f.presence.batteryLevel,
                        isCharging:   obj["isCharging"] as? Bool ?? f.presence.isCharging,
                        movement:     MovementState(rawValue: obj["movement"] as? String ?? "") ?? f.presence.movement,
                        speedKmh:     0
                    ),
                    locationName: f.locationName, lastUpdated: Date(),
                    isFavorite: f.isFavorite, isGhostMode: f.isGhostMode
                )
            }
        default: break
        }
        for cont in friendContinuations.values { cont.yield(latestFriends) }
    }

    // MARK: - HTTP helpers

    private func req(_ method: String, path: String, body: [String: Any]? = nil, auth: Bool = true) async throws -> [String: Any] {
        var r = URLRequest(url: base.appendingPathComponent(path))
        r.httpMethod = method
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if auth, let tok = token { r.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization") }
        if let body { r.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await URLSession.shared.data(for: r)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if code >= 400 { throw BackendError.network(json["error"] as? String ?? "HTTP \(code)") }
        return json
    }

    private func post(_ path: String, body: [String: Any], auth: Bool = true) async throws -> [String: Any] {
        try await req("POST", path: path, body: body, auth: auth)
    }
    private func patch(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        try await req("PATCH", path: path, body: body)
    }
    private func delete(_ path: String) async throws -> [String: Any] {
        try await req("DELETE", path: path)
    }
    private func getArray(_ path: String) async throws -> [[String: Any]] {
        var r = URLRequest(url: base.appendingPathComponent(path))
        if let tok = token { r.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await URLSession.shared.data(for: r)
        return (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] ?? []
    }
    private func fetchMessages(conversationId: String) async throws -> [Message] {
        let me = cachedUser?.id ?? ""
        let arr = try await getArray("/conversations/\(conversationId)/messages")
        return arr.compactMap { decodeMessage($0, myId: me) }
    }

    // MARK: - Decoders

    private func decodeUser(_ d: [String: Any], phone: String) -> UserProfile {
        UserProfile(
            id:          d["id"]          as? String ?? UUID().uuidString,
            displayName: d["displayName"] as? String ?? "",
            bio:         d["bio"]         as? String ?? "",
            avatar:      .default,
            inviteCode:  d["inviteCode"]  as? String ?? "",
            phoneNumber: phone
        )
    }

    private func decodeFriend(_ d: [String: Any]) -> Friend? {
        guard let id = d["id"] as? String else { return nil }
        let c = d["coordinate"] as? [String: Any]
        let coord = c.flatMap { cc -> Coordinate? in
            guard let lat = cc["latitude"] as? Double, let lon = cc["longitude"] as? Double else { return nil }
            return Coordinate(latitude: lat, longitude: lon)
        } ?? Coordinate(latitude: 0, longitude: 0)
        let p = d["presence"] as? [String: Any] ?? [:]
        return Friend(
            id:           id,
            displayName:  d["displayName"] as? String ?? "",
            avatar:       .default,
            coordinate:   coord,
            presence:     PresenceState(
                batteryLevel: p["batteryLevel"] as? Int ?? 100,
                isCharging:   p["isCharging"]   as? Bool ?? false,
                movement:     MovementState(rawValue: p["movement"] as? String ?? "") ?? .stationary,
                speedKmh:     0
            ),
            locationName: "",
            lastUpdated:  Date(),
            isFavorite:   false,
            isGhostMode:  false
        )
    }

    private func decodeConversation(_ d: [String: Any]) -> Conversation? {
        guard let id = d["id"] as? String else { return nil }
        let p = d["participant"] as? [String: Any] ?? [:]
        return Conversation(
            id:                  id,
            friendId:            p["id"]          as? String ?? "",
            friendName:          p["displayName"]  as? String ?? "",
            friendAvatar:        .default,
            lastMessagePreview:  d["lastMessage"]  as? String ?? "",
            lastMessageDate:     Date(),
            unreadCount:         0
        )
    }

    private func decodeMessage(_ d: [String: Any], myId: String) -> Message? {
        guard let id       = d["id"]           as? String,
              let content  = d["content"]       as? String,
              let senderId = d["senderId"]       as? String,
              let convId   = d["conversationId"] as? String
        else { return nil }
        return Message(id: id, conversationId: convId, senderId: senderId,
                       kind: .text(content), date: Date(),
                       isRead: senderId == myId)
    }

    private func decodePlace(_ d: [String: Any]) -> Place? {
        guard let id = d["id"] as? String, let name = d["name"] as? String else { return nil }
        let c = d["coordinate"] as? [String: Any]
        let coord = c.flatMap { cc -> Coordinate? in
            guard let lat = cc["latitude"] as? Double, let lon = cc["longitude"] as? Double else { return nil }
            return Coordinate(latitude: lat, longitude: lon)
        } ?? Coordinate(latitude: 0, longitude: 0)
        return Place(id: id, name: name, emoji: d["emoji"] as? String ?? "📍",
                     coordinate: coord,
                     visitCount: d["visitCount"] as? Int ?? 1, lastVisit: Date())
    }
}
