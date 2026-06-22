import Foundation

public struct Friend: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var displayName: String
    public var avatar: AvatarConfig
    public var coordinate: Coordinate
    public var presence: PresenceState
    public var locationName: String
    public var lastUpdated: Date
    public var isFavorite: Bool
    public var isGhostMode: Bool

    public init(id: String, displayName: String, avatar: AvatarConfig,
                coordinate: Coordinate, presence: PresenceState, locationName: String,
                lastUpdated: Date, isFavorite: Bool, isGhostMode: Bool) {
        self.id = id; self.displayName = displayName; self.avatar = avatar
        self.coordinate = coordinate; self.presence = presence
        self.locationName = locationName; self.lastUpdated = lastUpdated
        self.isFavorite = isFavorite; self.isGhostMode = isGhostMode
    }

    public func distance(from origin: Coordinate?) -> String {
        guard let origin else { return "—" }
        return coordinate.distance(to: origin).readableDistance
    }
}
