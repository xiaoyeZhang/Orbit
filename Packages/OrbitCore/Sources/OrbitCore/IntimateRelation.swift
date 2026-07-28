import Foundation

// MARK: - 亲密关系状态
/// 亲密关系的类型，对应 Jagat 的「情侣 / 密友 / 家人」情感连接。
public enum BondStatus: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
    case dating = "恋爱中"
    case bestie = "密友"
    case family = "家人"

    public var id: String { rawValue }

    public var emoji: String {
        switch self {
        case .dating: return "💞"
        case .bestie: return "🤝"
        case .family: return "🏡"
        }
    }
}

// MARK: - 纪念日
public struct Anniversary: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let emoji: String
    public let date: Date
    public let note: String

    public init(id: String, title: String, emoji: String, date: Date, note: String) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.date = date
        self.note = note
    }
}

// MARK: - 亲密关系
/// 当前用户与一位密友 / 情侣 / 家人绑定的专属关系。
/// 这是「亲密关系专属」模块的核心数据，承载在一起天数、纪念日倒数等情感连接。
public struct IntimateRelation: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let partnerName: String
    public let partnerAvatar: AvatarConfig
    public let status: BondStatus
    public let bondDate: Date
    public let moodEmoji: String
    public let anniversaries: [Anniversary]

    public init(
        id: String,
        partnerName: String,
        partnerAvatar: AvatarConfig,
        status: BondStatus,
        bondDate: Date,
        moodEmoji: String,
        anniversaries: [Anniversary]
    ) {
        self.id = id
        self.partnerName = partnerName
        self.partnerAvatar = partnerAvatar
        self.status = status
        self.bondDate = bondDate
        self.moodEmoji = moodEmoji
        self.anniversaries = anniversaries
    }

    /// 在一起 / 建立关系至今的天数。
    public var daysTogether: Int {
        Calendar.current.dateComponents([.day], from: bondDate, to: Date()).day ?? 0
    }

    /// 下一个尚未到来的纪念日（按日期升序）。
    public var nextAnniversary: Anniversary? {
        anniversaries
            .filter { $0.date > Date() }
            .sorted { $0.date < $1.date }
            .first
    }

    /// 距离下一个纪念日的天数（无则 0）。
    public var nextAnniversaryCountdown: Int {
        guard let date = nextAnniversary?.date else { return 0 }
        return Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
    }

    public static var sample: IntimateRelation {
        let now = Date()
        let cal = Calendar.current
        let bond     = cal.date(byAdding: .day, value: -218, to: now) ?? now   // 在一起 218 天
        let hundred  = cal.date(byAdding: .day, value: -118, to: now) ?? now   // 100 天（已过）
        let birthday = cal.date(byAdding: .day, value: 63,  to: now) ?? now    // 小月生日（约 2 个月后）
        let oneYear  = cal.date(byAdding: .day, value: 147, to: now) ?? now    // 一周年（约 5 个月后）

        return IntimateRelation(
            id: "rel-me",
            partnerName: "小月",
            partnerAvatar: .default,
            status: .dating,
            bondDate: bond,
            moodEmoji: "😊",
            anniversaries: [
                Anniversary(id: "a1", title: "在一起",   emoji: "💞", date: bond,    note: "我们的开始"),
                Anniversary(id: "a2", title: "100 天",   emoji: "💯", date: hundred,  note: "小确幸满满"),
                Anniversary(id: "a3", title: "小月生日", emoji: "🎉", date: birthday, note: "要准备惊喜呀"),
                Anniversary(id: "a4", title: "一周年",   emoji: "🎂", date: oneYear,  note: "期待的第一个周年"),
            ]
        )
    }
}
