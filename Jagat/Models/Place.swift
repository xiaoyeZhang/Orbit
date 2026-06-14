import Foundation

/// 足迹 / 常去地点（Jagat 的「Places」）。
struct Place: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var emoji: String
    var coordinate: Coordinate
    var visitCount: Int
    var lastVisit: Date
}
