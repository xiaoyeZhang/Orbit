import Foundation

public struct Conversation: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var friendId: String
    public var friendName: String
    public var friendAvatar: AvatarConfig
    public var lastMessagePreview: String
    public var lastMessageDate: Date
    public var unreadCount: Int

    public init(id: String, friendId: String, friendName: String, friendAvatar: AvatarConfig,
                lastMessagePreview: String, lastMessageDate: Date, unreadCount: Int) {
        self.id = id; self.friendId = friendId; self.friendName = friendName
        self.friendAvatar = friendAvatar; self.lastMessagePreview = lastMessagePreview
        self.lastMessageDate = lastMessageDate; self.unreadCount = unreadCount
    }
}

public struct Message: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var conversationId: String
    public var senderId: String
    public var kind: Kind
    public var date: Date
    public var isRead: Bool

    public init(id: String, conversationId: String, senderId: String,
                kind: Kind, date: Date, isRead: Bool) {
        self.id = id; self.conversationId = conversationId; self.senderId = senderId
        self.kind = kind; self.date = date; self.isRead = isRead
    }

    public enum Kind: Codable, Equatable, Sendable {
        case text(String)
        case location(Coordinate, name: String)
        case ping
    }

    public var isMine: Bool { senderId == "me" }

    public var preview: String {
        switch kind {
        case .text(let t):          return t
        case .location(_, let n):   return "📍 \(n)"
        case .ping:                 return "👋 戳了你一下"
        }
    }
}
