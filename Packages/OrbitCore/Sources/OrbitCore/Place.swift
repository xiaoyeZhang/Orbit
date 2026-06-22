import Foundation

public struct Place: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var emoji: String
    public var coordinate: Coordinate
    public var visitCount: Int
    public var lastVisit: Date

    public init(id: String, name: String, emoji: String,
                coordinate: Coordinate, visitCount: Int, lastVisit: Date) {
        self.id = id; self.name = name; self.emoji = emoji
        self.coordinate = coordinate; self.visitCount = visitCount; self.lastVisit = lastVisit
    }
}
