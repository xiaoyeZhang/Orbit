import Foundation
import OrbitCore

public enum SampleData {
    public static let cityCenter = Coordinate(latitude: 39.9042, longitude: 116.4074)

    public static let friends: [Friend] = [
        Friend(id: "f1", displayName: "小雨",
               avatar: AvatarConfig(skinTone: .light, hair: .long, hairColor: .black, accessory: .none, background: .pink),
               coordinate: Coordinate(latitude: 39.9087, longitude: 116.3975),
               presence: PresenceState(batteryLevel: 82, isCharging: false, movement: .walking, speedKmh: 4.5),
               locationName: "西单大悦城", lastUpdated: Date().addingTimeInterval(-120),
               isFavorite: true, isGhostMode: false),
        Friend(id: "f2", displayName: "阿哲",
               avatar: AvatarConfig(skinTone: .medium, hair: .short, hairColor: .brown, accessory: .glasses, background: .sky),
               coordinate: Coordinate(latitude: 39.9151, longitude: 116.4210),
               presence: PresenceState(batteryLevel: 17, isCharging: false, movement: .driving, speedKmh: 38),
               locationName: "东四环辅路", lastUpdated: Date().addingTimeInterval(-40),
               isFavorite: true, isGhostMode: false),
        Friend(id: "f3", displayName: "Mia",
               avatar: AvatarConfig(skinTone: .tan, hair: .bun, hairColor: .blonde, accessory: .none, background: .sunshine),
               coordinate: Coordinate(latitude: 39.8965, longitude: 116.4112),
               presence: PresenceState(batteryLevel: 95, isCharging: true, movement: .stationary, speedKmh: 0),
               locationName: "天安门广场", lastUpdated: Date().addingTimeInterval(-600),
               isFavorite: false, isGhostMode: false),
        Friend(id: "f4", displayName: "老王",
               avatar: AvatarConfig(skinTone: .medium, hair: .bald, hairColor: .black, accessory: .none, background: .mint),
               coordinate: Coordinate(latitude: 39.9220, longitude: 116.3900),
               presence: PresenceState(batteryLevel: 60, isCharging: false, movement: .stationary, speedKmh: 0),
               locationName: "什刹海", lastUpdated: Date().addingTimeInterval(-1800),
               isFavorite: false, isGhostMode: false),
        Friend(id: "f5", displayName: "Coco",
               avatar: AvatarConfig(skinTone: .deep, hair: .long, hairColor: .pink, accessory: .cap, background: .violet),
               coordinate: Coordinate(latitude: 39.9012, longitude: 116.4300),
               presence: PresenceState(batteryLevel: 44, isCharging: false, movement: .walking, speedKmh: 5),
               locationName: "国贸 CBD", lastUpdated: Date().addingTimeInterval(-300),
               isFavorite: false, isGhostMode: true),
    ]

    public static let conversations: [Conversation] = [
        Conversation(id: "c1", friendId: "f1", friendName: "小雨", friendAvatar: friends[0].avatar,
                     lastMessagePreview: "晚点约个饭？", lastMessageDate: Date().addingTimeInterval(-200), unreadCount: 2),
        Conversation(id: "c2", friendId: "f2", friendName: "阿哲", friendAvatar: friends[1].avatar,
                     lastMessagePreview: "📍 东四环辅路", lastMessageDate: Date().addingTimeInterval(-1200), unreadCount: 0),
        Conversation(id: "c3", friendId: "f3", friendName: "Mia", friendAvatar: friends[2].avatar,
                     lastMessagePreview: "👋 戳了你一下", lastMessageDate: Date().addingTimeInterval(-3600), unreadCount: 0),
    ]

    public static let messages: [String: [Message]] = [
        "c1": [
            Message(id: "m1", conversationId: "c1", senderId: "f1", kind: .text("在干嘛呀"), date: Date().addingTimeInterval(-900), isRead: true),
            Message(id: "m2", conversationId: "c1", senderId: "me", kind: .text("在公司搬砖 😮‍💨"), date: Date().addingTimeInterval(-800), isRead: true),
            Message(id: "m3", conversationId: "c1", senderId: "f1", kind: .text("晚点约个饭？"), date: Date().addingTimeInterval(-200), isRead: false),
        ],
        "c2": [
            Message(id: "m4", conversationId: "c2", senderId: "f2",
                    kind: .location(Coordinate(latitude: 39.9151, longitude: 116.4210), name: "东四环辅路"),
                    date: Date().addingTimeInterval(-1200), isRead: true),
        ],
        "c3": [
            Message(id: "m5", conversationId: "c3", senderId: "f3", kind: .ping, date: Date().addingTimeInterval(-3600), isRead: true),
        ],
    ]

    public static let places: [Place] = [
        Place(id: "p1", name: "公司", emoji: "🏢",
              coordinate: Coordinate(latitude: 39.9042, longitude: 116.4200), visitCount: 128, lastVisit: Date().addingTimeInterval(-3600)),
        Place(id: "p2", name: "家", emoji: "🏠",
              coordinate: Coordinate(latitude: 39.9300, longitude: 116.3800), visitCount: 240, lastVisit: Date().addingTimeInterval(-28800)),
        Place(id: "p3", name: "常去的咖啡馆", emoji: "☕️",
              coordinate: Coordinate(latitude: 39.9100, longitude: 116.4100), visitCount: 36, lastVisit: Date().addingTimeInterval(-86400)),
    ]

    private static let names = ["Leo", "Nina", "大头", "Sky", "糖糖", "阿杰", "Yuki", "胖虎"]
    public static func randomName() -> String { names.randomElement() ?? "新朋友" }
    public static func randomAvatar() -> AvatarConfig {
        AvatarConfig(
            skinTone: AvatarConfig.SkinTone.allCases.randomElement()!,
            hair: AvatarConfig.HairStyle.allCases.randomElement()!,
            hairColor: AvatarConfig.HairColor.allCases.randomElement()!,
            accessory: AvatarConfig.Accessory.allCases.randomElement()!,
            background: AvatarConfig.BackgroundStyle.allCases.randomElement()!
        )
    }
}
