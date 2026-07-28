import Foundation

/// AI 轨迹日记：把一段时间内的轨迹自动摘要成一段可分享的「故事」。
/// Jagat 弱 / 没有这个能力，是 Orbit 的差异化亮点之一。
public struct TrajectoryDiary: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String          // 例如「周日的城市漫游」
    public var date: Date
    public var coverEmoji: String      // 封面情绪图标
    public var story: String           // AI 生成的叙事正文
    public var highlights: [DiaryHighlight]   // 途经的地点 / 事件
    public var distanceKm: Double      // 当日移动距离
    public var durationLabel: String   // 例如「活跃 6 小时」
    public var mood: String            // 例如「惬意」
    public var placesVisited: Int

    public init(id: String, title: String, date: Date, coverEmoji: String,
                story: String, highlights: [DiaryHighlight],
                distanceKm: Double, durationLabel: String, mood: String, placesVisited: Int) {
        self.id = id; self.title = title; self.date = date; self.coverEmoji = coverEmoji
        self.story = story; self.highlights = highlights
        self.distanceKm = distanceKm; self.durationLabel = durationLabel
        self.mood = mood; self.placesVisited = placesVisited
    }

    /// 分享文案：把日记拼成一段可直接发出去的文本。
    public var shareText: String {
        var lines = [coverEmoji + " " + title, ""]
        lines.append(story)
        lines.append("")
        lines.append("📍 途经 \(placesVisited) 个地方 · 漫游 \(String(format: "%.1f", distanceKm)) km")
        lines.append(" via Orbit")
        return lines.joined(separator: "\n")
    }

    // MARK: - 内置示例（供协议默认实现与预览使用）
    public static let sample: TrajectoryDiary = {
        let cal = Calendar.current
        let d = cal.date(byAdding: .day, value: -1, to: Date())!
        return TrajectoryDiary(
            id: "diary-sample",
            title: "昨日的城市漫游",
            date: d,
            coverEmoji: "🌇",
            story: "昨天你从公司出发，傍晚拐进常去的咖啡馆坐了一会儿，又在什刹海边散了散步。一整天节奏不紧不慢，像是特意留给自己的喘息。",
            highlights: [
                .init(id: "h1", placeName: "公司", emoji: "🏢", note: "上午在工位上忙完了一桩大事", time: "09:20"),
                .init(id: "h2", placeName: "常去的咖啡馆", emoji: "☕️", note: "点了杯手冲，发了一会儿呆", time: "15:40"),
                .init(id: "h3", placeName: "什刹海", emoji: "🌊", note: "夕阳下走了两圈，风很舒服", time: "18:10"),
            ],
            distanceKm: 7.3,
            durationLabel: "活跃 9 小时",
            mood: "惬意",
            placesVisited: 3
        )
    }()
}

public struct DiaryHighlight: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var placeName: String
    public var emoji: String
    public var note: String
    public var time: String

    public init(id: String, placeName: String, emoji: String, note: String, time: String) {
        self.id = id; self.placeName = placeName; self.emoji = emoji
        self.note = note; self.time = time
    }
}
