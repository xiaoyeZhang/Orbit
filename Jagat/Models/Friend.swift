import Foundation

/// 一位好友及其当前位置 / 状态快照（地图气泡、好友列表共用）。
struct Friend: Codable, Equatable, Identifiable {
    var id: String
    var displayName: String
    var avatar: AvatarConfig
    var coordinate: Coordinate
    var presence: PresenceState
    var locationName: String       // 反向地理位置的人类可读名
    var lastUpdated: Date
    var isFavorite: Bool           // 置顶 / 特别关心
    var isGhostMode: Bool          // 隐身（Jagat 的「隐身/冻结位置」）

    /// 距离指定坐标多远。
    func distance(from origin: Coordinate?) -> String {
        guard let origin else { return "—" }
        return coordinate.distance(to: origin).readableDistance
    }
}
