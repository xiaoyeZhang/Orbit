import Foundation

/// 一条会话（一对一）。
struct Conversation: Codable, Equatable, Identifiable {
    var id: String
    var friendId: String
    var friendName: String
    var friendAvatar: AvatarConfig
    var lastMessagePreview: String
    var lastMessageDate: Date
    var unreadCount: Int
}

/// 一条消息。支持文本与位置分享两种类型（Jagat 常见的「分享位置」气泡）。
struct Message: Codable, Equatable, Identifiable {
    var id: String
    var conversationId: String
    var senderId: String           // "me" 表示自己发出
    var kind: Kind
    var date: Date
    var isRead: Bool

    enum Kind: Codable, Equatable {
        case text(String)
        case location(Coordinate, name: String)
        case ping                  // 「戳一下」
    }

    var isMine: Bool { senderId == "me" }

    var preview: String {
        switch kind {
        case .text(let t): return t
        case .location(_, let name): return "📍 \(name)"
        case .ping: return "👋 戳了你一下"
        }
    }
}
