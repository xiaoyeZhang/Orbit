import Foundation

/// 谁能在「城市脉搏」里看到我 / 我能看到谁。
/// 这是泛社交能力的隐私总开关，默认「仅好友」——只在你已认识的人脉范围内可见。
public enum CityPulseVisibility: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case off          // 完全关闭，不出现在任何人的脉搏里，也看不到别人的
    case friendsOnly  // 仅通过共同好友关系可见（好友的好友），不暴露给陌生人
    case everyone     // 同城范围内可见
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .off:         return "关闭"
        case .friendsOnly: return "仅好友人脉"
        case .everyone:    return "同城可见"
        }
    }
}

/// 「城市脉搏」：把附近的人与同城活动聚合成一屏可逛的发现流（泛社交，区别于紧密好友）。
public struct CityPulse: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var generatedAt: Date
    public var visibility: CityPulseVisibility
    public var nearby: [NearbyPerson]
    public var events: [CityEvent]

    public init(id: String, generatedAt: Date, visibility: CityPulseVisibility,
                nearby: [NearbyPerson], events: [CityEvent]) {
        self.id = id; self.generatedAt = generatedAt; self.visibility = visibility
        self.nearby = nearby; self.events = events
    }

    public static let sample: CityPulse = {
        let now = Date()
        return CityPulse(
            id: "pulse-sample",
            generatedAt: now,
            visibility: .friendsOnly,
            nearby: [
                .init(id: "np1", displayName: "小满", avatar: .init(skinTone: .light, hair: .long,
                       hairColor: .black, accessory: .none, background: .pink),
                       distanceKm: 1.2, mutualFriends: ["小雨", "阿哲"], lastSeenText: "10 分钟前在线"),
                .init(id: "np2", displayName: "Kai", avatar: .init(skinTone: .medium, hair: .short,
                       hairColor: .brown, accessory: .glasses, background: .sky),
                       distanceKm: 2.6, mutualFriends: ["Mia"], lastSeenText: "刚刚"),
                .init(id: "np3", displayName: "阿橙", avatar: .init(skinTone: .tan, hair: .bun,
                       hairColor: .blonde, accessory: .none, background: .sunshine),
                       distanceKm: 0.8, mutualFriends: ["老王"], lastSeenText: "30 分钟前在线"),
            ],
            events: [
                .init(id: "ev1", title: "鼓楼夜骑", emoji: "🚲", placeName: "鼓楼大街",
                      startsIn: "今晚 19:30", attendees: 12, category: "运动"),
                .init(id: "ev2", title: "天台电影夜", emoji: "🎬", placeName: "国贸某天台",
                      startsIn: "今晚 20:00", attendees: 8, category: "休闲"),
                .init(id: "ev3", title: "周末市集", emoji: "🛍️", placeName: "798 艺术区",
                      startsIn: "周六 14:00", attendees: 56, category: "逛街"),
            ]
        )
    }()
}

public struct NearbyPerson: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var displayName: String
    public var avatar: AvatarConfig
    public var distanceKm: Double
    public var mutualFriends: [String]   // 共同好友昵称
    public var lastSeenText: String

    public init(id: String, displayName: String, avatar: AvatarConfig,
                distanceKm: Double, mutualFriends: [String], lastSeenText: String) {
        self.id = id; self.displayName = displayName; self.avatar = avatar
        self.distanceKm = distanceKm; self.mutualFriends = mutualFriends; self.lastSeenText = lastSeenText
    }
}

public struct CityEvent: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var emoji: String
    public var placeName: String
    public var startsIn: String
    public var attendees: Int
    public var category: String

    public init(id: String, title: String, emoji: String, placeName: String,
                startsIn: String, attendees: Int, category: String) {
        self.id = id; self.title = title; self.emoji = emoji; self.placeName = placeName
        self.startsIn = startsIn; self.attendees = attendees; self.category = category
    }
}
