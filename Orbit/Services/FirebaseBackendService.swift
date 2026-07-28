//
//  FirebaseBackendService.swift
//  真实后端实现：Firebase Auth（手机号登录）+ Cloud Firestore（实时位置 / 聊天）。
//
//  ⚠️ 整份文件用 `#if ORBIT_FIREBASE` 守护（该编译标志由生成器在 ENABLE_FIREBASE=1 时注入）：
//     - 未启用 Firebase 时，此文件编译为空，工程照常用 Mock 构建运行。
//     - 用 `ENABLE_FIREBASE=1 python3 Scripts/generate_xcodeproj.py` 重新生成工程后，
//       ORBIT_FIREBASE 生效、SDK 被链接，本实现激活；再把 backendKind 改为 .firebase 即可。
//     （用显式编译标志而非 canImport，可避免切换模式时受 DerivedData 缓存影响。）
//
//  Firestore 数据结构见 FIREBASE_SETUP.md，安全规则见 firestore.rules。
//

#if ORBIT_FIREBASE
import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import OrbitCore

@MainActor
final class FirebaseBackendService: BackendService {

    private let db: Firestore
    private var cachedUser: UserProfile?
    private var verificationID: String?

    // 好友实时流相关
    private var friendsContinuation: AsyncStream<[Friend]>.Continuation?
    private var friendEdgesListener: ListenerRegistration?
    private var friendDocListeners: [String: ListenerRegistration] = [:]
    private var friendCache: [String: Friend] = [:]
    private var favoriteCache: [String: Bool] = [:]

    // 聊天实时流相关
    private var messageListeners: [String: ListenerRegistration] = [:]
    private var messageContinuations: [String: AsyncStream<[Message]>.Continuation] = [:]

    init() {
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        db = Firestore.firestore()
    }

    // MARK: - 鉴权（手机号 + 短信验证码）
    func requestVerificationCode(phone: String) async throws {
        let e164 = Self.normalize(phone)
        verificationID = try await withCheckedThrowingContinuation { cont in
            PhoneAuthProvider.provider().verifyPhoneNumber(e164, uiDelegate: nil) { id, error in
                if let error = error { cont.resume(throwing: error) }
                else { cont.resume(returning: id ?? "") }
            }
        }
    }

    func signIn(phone: String, code: String) async throws -> UserProfile {
        guard let vid = verificationID, !vid.isEmpty else { throw BackendError.invalidCode }
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: vid, verificationCode: code)
        let result = try await Auth.auth().signIn(with: credential)
        let profile = try await loadOrCreateProfile(uid: result.user.uid, phone: phone)
        cachedUser = profile
        return profile
    }

    func currentUser() -> UserProfile? { cachedUser }

    func signOut() {
        try? Auth.auth().signOut()
        cachedUser = nil
        removeAllListeners()
    }

    func updateProfile(_ profile: UserProfile) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw BackendError.notAuthenticated }
        try await userRef(uid).setData([
            "displayName": profile.displayName,
            "bio": profile.bio,
            "inviteCode": profile.inviteCode,
            "phoneNumber": profile.phoneNumber as Any,
            "avatar": avatarDict(profile.avatar),
        ], merge: true)
        cachedUser = profile
    }

    // MARK: - 好友
    func fetchFriends() async throws -> [Friend] {
        guard let uid = Auth.auth().currentUser?.uid else { throw BackendError.notAuthenticated }
        let edges = try await userRef(uid).collection("friends").getDocuments()
        var result: [Friend] = []
        for edge in edges.documents {
            let fid = edge.documentID
            let isFav = edge.data()["isFavorite"] as? Bool ?? false
            if let data = try? await userRef(fid).getDocument().data() {
                result.append(friend(from: data, uid: fid, isFavorite: isFav))
            }
        }
        return result
    }

    /// 实时好友位置：监听「好友边」集合，再对每位好友的 user 文档建快照监听，任一变化即推送。
    func friendsStream() -> AsyncStream<[Friend]> {
        AsyncStream { continuation in
            self.friendsContinuation = continuation
            guard let uid = Auth.auth().currentUser?.uid else { continuation.finish(); return }

            self.friendEdgesListener = self.userRef(uid).collection("friends")
                .addSnapshotListener { snapshot, _ in
                    let edges: [(String, Bool)] = (snapshot?.documents ?? []).map {
                        ($0.documentID, $0.data()["isFavorite"] as? Bool ?? false)
                    }
                    Task { @MainActor [weak self] in self?.handleFriendEdges(edges) }
                }

            continuation.onTermination = { @Sendable _ in
                Task { @MainActor [weak self] in self?.removeFriendListeners() }
            }
        }
    }

    func addFriend(inviteCode: String) async throws -> Friend {
        guard let uid = Auth.auth().currentUser?.uid else { throw BackendError.notAuthenticated }
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let codeDoc = try await db.collection("inviteCodes").document(code).getDocument()
        guard let friendUid = codeDoc.data()?["uid"] as? String, friendUid != uid else {
            throw BackendError.invalidCode
        }
        let now = FieldValue.serverTimestamp()
        try await userRef(uid).collection("friends").document(friendUid)
            .setData(["isFavorite": false, "since": now])
        try await userRef(friendUid).collection("friends").document(uid)
            .setData(["isFavorite": false, "since": now])
        guard let data = try? await userRef(friendUid).getDocument().data() else {
            throw BackendError.friendNotFound
        }
        return friend(from: data, uid: friendUid, isFavorite: false)
    }

    func removeFriend(id: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw BackendError.notAuthenticated }
        try await userRef(uid).collection("friends").document(id).delete()
        try await userRef(id).collection("friends").document(uid).delete()
    }

    func setFavorite(friendId: String, isFavorite: Bool) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw BackendError.notAuthenticated }
        try await userRef(uid).collection("friends").document(friendId)
            .setData(["isFavorite": isFavorite], merge: true)
    }

    func setGhostMode(_ on: Bool) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw BackendError.notAuthenticated }
        try await userRef(uid).setData(["ghostMode": on], merge: true)
    }

    // MARK: - 位置上报
    func updateMyLocation(_ coordinate: Coordinate) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw BackendError.notAuthenticated }
        try await userRef(uid).setData([
            "location": [
                "lat": coordinate.latitude,
                "lng": coordinate.longitude,
                "updatedAt": FieldValue.serverTimestamp(),
            ]
        ], merge: true)
    }

    func updatePresence(_ presence: PresenceState) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw BackendError.notAuthenticated }
        try await userRef(uid).setData([
            "presence": [
                "batteryLevel": presence.batteryLevel,
                "isCharging": presence.isCharging,
                "movement": presence.movement.rawValue,
                "speedKmh": presence.speedKmh,
            ]
        ], merge: true)
    }

    // MARK: - 聊天
    func fetchConversations() async throws -> [Conversation] {
        guard let uid = Auth.auth().currentUser?.uid else { throw BackendError.notAuthenticated }
        let snap = try await db.collection("conversations")
            .whereField("members", arrayContains: uid)
            .getDocuments()
        return snap.documents.compactMap { conversation(from: $0, myUid: uid) }
    }

    func messagesStream(conversationId: String) -> AsyncStream<[Message]> {
        AsyncStream { continuation in
            self.messageContinuations[conversationId] = continuation
            let listener = self.db.collection("conversations").document(conversationId)
                .collection("messages").order(by: "date")
                .addSnapshotListener { snapshot, _ in
                    let docs = snapshot?.documents ?? []
                    let myUid = Auth.auth().currentUser?.uid
                    let messages = docs.map { Self.message(from: $0, cid: conversationId, myUid: myUid) }
                    Task { @MainActor [weak self] in
                        self?.messageContinuations[conversationId]?.yield(messages)
                    }
                }
            self.messageListeners[conversationId] = listener
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor [weak self] in
                    self?.messageListeners[conversationId]?.remove()
                    self?.messageListeners[conversationId] = nil
                    self?.messageContinuations[conversationId] = nil
                }
            }
        }
    }

    func sendMessage(_ kind: Message.Kind, to conversationId: String) async throws -> Message {
        guard let uid = Auth.auth().currentUser?.uid else { throw BackendError.notAuthenticated }
        let convoRef = db.collection("conversations").document(conversationId)
        // 首次发消息时补建会话文档（成员 = 当前用户 + 对端）。
        let parts = conversationId.split(separator: "_").map(String.init)
        let members = parts.count == 2 ? parts : [uid]
        try await convoRef.setData([
            "members": members,
            "lastMessage": preview(of: kind),
            "lastMessageDate": FieldValue.serverTimestamp(),
        ], merge: true)
        // 该 Firebase 版本提供 async 重载，await 写入完成后返回文档引用。
        let ref = try await convoRef.collection("messages").addDocument(data: messageFields(kind, senderId: uid))
        return Message(id: ref.documentID, conversationId: conversationId,
                       senderId: "me", kind: kind, date: Date(), isRead: true)
    }

    func markRead(conversationId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await db.collection("conversations").document(conversationId)
            .setData(["unread": [uid: 0]], merge: true)
    }

    // MARK: - 足迹
    func fetchPlaces() async throws -> [Place] {
        guard let uid = Auth.auth().currentUser?.uid else { throw BackendError.notAuthenticated }
        let snap = try await userRef(uid).collection("places").getDocuments()
        return snap.documents.compactMap { doc in
            let d = doc.data()
            guard let loc = d["location"] as? [String: Any] else { return nil }
            return Place(
                id: doc.documentID,
                name: d["name"] as? String ?? "",
                emoji: d["emoji"] as? String ?? "📍",
                coordinate: Coordinate(latitude: loc["lat"] as? Double ?? 0, longitude: loc["lng"] as? Double ?? 0),
                visitCount: d["visitCount"] as? Int ?? 0,
                lastVisit: (d["lastVisit"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
    }

    // MARK: - 私有：好友流处理（均在主线程）
    private func handleFriendEdges(_ edges: [(String, Bool)]) {
        let ids = Set(edges.map { $0.0 })
        for (fid, fav) in edges { favoriteCache[fid] = fav }

        // 移除已不是好友的监听与缓存
        for removed in Array(friendDocListeners.keys) where !ids.contains(removed) {
            friendDocListeners[removed]?.remove()
            friendDocListeners[removed] = nil
            friendCache[removed] = nil
        }
        // 为新好友建立 user 文档监听
        for fid in ids where friendDocListeners[fid] == nil {
            let reg = userRef(fid).addSnapshotListener { snapshot, _ in
                let data = snapshot?.data()
                Task { @MainActor [weak self] in self?.handleFriendDoc(fid: fid, data: data) }
            }
            friendDocListeners[fid] = reg
        }
        // 更新已有好友的关注标记
        for (fid, fav) in favoriteCache where friendCache[fid] != nil {
            friendCache[fid]?.isFavorite = fav
        }
        emitFriends()
    }

    private func handleFriendDoc(fid: String, data: [String: Any]?) {
        guard let data = data else { return }
        friendCache[fid] = friend(from: data, uid: fid, isFavorite: favoriteCache[fid] ?? false)
        emitFriends()
    }

    private func emitFriends() {
        friendsContinuation?.yield(Array(friendCache.values))
    }

    private func removeFriendListeners() {
        friendEdgesListener?.remove(); friendEdgesListener = nil
        friendDocListeners.values.forEach { $0.remove() }
        friendDocListeners.removeAll()
        friendCache.removeAll()
        favoriteCache.removeAll()
        friendsContinuation = nil
    }

    private func removeAllListeners() {
        removeFriendListeners()
        messageListeners.values.forEach { $0.remove() }
        messageListeners.removeAll()
        messageContinuations.removeAll()
    }

    // MARK: - 私有：Firestore 引用 & 资料
    private func userRef(_ uid: String) -> DocumentReference {
        db.collection("users").document(uid)
    }

    private func loadOrCreateProfile(uid: String, phone: String) async throws -> UserProfile {
        let ref = userRef(uid)
        let snap = try await ref.getDocument()
        if let data = snap.data(), let name = data["displayName"] as? String {
            return UserProfile(
                id: uid, displayName: name,
                bio: data["bio"] as? String ?? "",
                avatar: avatar(from: data["avatar"] as? [String: Any]),
                inviteCode: data["inviteCode"] as? String ?? "",
                phoneNumber: data["phoneNumber"] as? String ?? phone,
                isGhostMode: data["ghostMode"] as? Bool ?? false
            )
        }
        // 首次登录：创建资料 + 邀请码索引
        let code = "ORBIT-" + String(UUID().uuidString.prefix(5)).uppercased()
        let profile = UserProfile(id: uid, displayName: "我", bio: "在路上 🚀",
                                  avatar: .default, inviteCode: code, phoneNumber: phone)
        try await ref.setData([
            "displayName": profile.displayName,
            "bio": profile.bio,
            "inviteCode": code,
            "phoneNumber": phone,
            "avatar": avatarDict(profile.avatar),
            "ghostMode": false,
        ], merge: true)
        try await db.collection("inviteCodes").document(code).setData(["uid": uid])
        return profile
    }

    // MARK: - 私有：映射
    private func friend(from data: [String: Any], uid: String, isFavorite: Bool) -> Friend {
        let loc = data["location"] as? [String: Any]
        let coord = Coordinate(latitude: loc?["lat"] as? Double ?? SampleData.cityCenter.latitude,
                               longitude: loc?["lng"] as? Double ?? SampleData.cityCenter.longitude)
        return Friend(
            id: uid,
            displayName: data["displayName"] as? String ?? "好友",
            avatar: avatar(from: data["avatar"] as? [String: Any]),
            coordinate: coord,
            presence: presence(from: data["presence"] as? [String: Any]),
            locationName: loc?["locationName"] as? String ?? "未知位置",
            lastUpdated: (loc?["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
            isFavorite: isFavorite,
            isGhostMode: data["ghostMode"] as? Bool ?? false
        )
    }

    private func conversation(from doc: QueryDocumentSnapshot, myUid: String) -> Conversation? {
        let d = doc.data()
        let members = d["members"] as? [String] ?? []
        let otherUid = members.first { $0 != myUid } ?? ""
        let names = d["names"] as? [String: String] ?? [:]
        let avatars = d["avatars"] as? [String: [String: Any]] ?? [:]
        let unread = d["unread"] as? [String: Int] ?? [:]
        return Conversation(
            id: doc.documentID,
            friendId: otherUid,
            friendName: names[otherUid] ?? "好友",
            friendAvatar: avatar(from: avatars[otherUid]),
            lastMessagePreview: d["lastMessage"] as? String ?? "",
            lastMessageDate: (d["lastMessageDate"] as? Timestamp)?.dateValue() ?? Date(),
            unreadCount: unread[myUid] ?? 0
        )
    }

    private func avatarDict(_ a: AvatarConfig) -> [String: Any] {
        ["skinTone": a.skinTone.rawValue, "hair": a.hair.rawValue,
         "hairColor": a.hairColor.rawValue, "accessory": a.accessory.rawValue,
         "background": a.background.rawValue]
    }

    private func avatar(from d: [String: Any]?) -> AvatarConfig {
        guard let d = d else { return .default }
        return AvatarConfig(
            skinTone: AvatarConfig.SkinTone(rawValue: d["skinTone"] as? String ?? "") ?? .medium,
            hair: AvatarConfig.HairStyle(rawValue: d["hair"] as? String ?? "") ?? .short,
            hairColor: AvatarConfig.HairColor(rawValue: d["hairColor"] as? String ?? "") ?? .brown,
            accessory: AvatarConfig.Accessory(rawValue: d["accessory"] as? String ?? "") ?? AvatarConfig.Accessory.none,
            background: AvatarConfig.BackgroundStyle(rawValue: d["background"] as? String ?? "") ?? .violet
        )
    }

    private func presence(from d: [String: Any]?) -> PresenceState {
        guard let d = d else { return .unknown }
        return PresenceState(
            batteryLevel: d["batteryLevel"] as? Int ?? 100,
            isCharging: d["isCharging"] as? Bool ?? false,
            movement: MovementState(rawValue: d["movement"] as? String ?? "") ?? .stationary,
            speedKmh: d["speedKmh"] as? Double ?? 0
        )
    }

    private func messageFields(_ kind: Message.Kind, senderId: String) -> [String: Any] {
        var d: [String: Any] = ["senderId": senderId, "date": FieldValue.serverTimestamp()]
        switch kind {
        case .text(let t): d["type"] = "text"; d["text"] = t
        case .location(let c, let name):
            d["type"] = "location"; d["lat"] = c.latitude; d["lng"] = c.longitude; d["locationName"] = name
        case .ping: d["type"] = "ping"
        case .sos(let c, let note):
            d["type"] = "sos"; d["lat"] = c.latitude; d["lng"] = c.longitude; d["note"] = note
        case .burst(let emoji):
            d["type"] = "burst"; d["emoji"] = emoji
        }
        return d
    }

    private func preview(of kind: Message.Kind) -> String {
        switch kind {
        case .text(let t): return t
        case .location(_, let name): return "📍 \(name)"
        case .ping: return "👋 戳了一下"
        case .sos(_, let note): return "🆘 \(note)"
        case .burst(let emoji): return "\(emoji) 轰炸"
        }
    }

    private static func message(from doc: QueryDocumentSnapshot, cid: String, myUid: String?) -> Message {
        let data = doc.data()
        let kind: Message.Kind
        switch data["type"] as? String {
        case "location":
            kind = .location(Coordinate(latitude: data["lat"] as? Double ?? 0,
                                        longitude: data["lng"] as? Double ?? 0),
                             name: data["locationName"] as? String ?? "")
        case "ping":
            kind = .ping
        case "sos":
            kind = .sos(Coordinate(latitude: data["lat"] as? Double ?? 0,
                                   longitude: data["lng"] as? Double ?? 0),
                        note: data["note"] as? String ?? "")
        case "burst":
            kind = .burst(data["emoji"] as? String ?? "🎉")
        default:
            kind = .text(data["text"] as? String ?? "")
        }
        let sender = data["senderId"] as? String ?? ""
        return Message(
            id: doc.documentID, conversationId: cid,
            senderId: (sender == myUid) ? "me" : sender,
            kind: kind,
            date: (data["date"] as? Timestamp)?.dateValue() ?? Date(),
            isRead: true
        )
    }

    private static func normalize(_ phone: String) -> String {
        let trimmed = phone.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("+") ? trimmed : "+86" + trimmed
    }
}
#endif
