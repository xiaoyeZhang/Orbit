import Foundation
import CoreLocation

public struct Coordinate: Codable, Equatable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    public var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    public init(_ c: CLLocationCoordinate2D) {
        self.latitude = c.latitude
        self.longitude = c.longitude
    }

    public func distance(to other: Coordinate) -> CLLocationDistance {
        clLocation.distance(from: other.clLocation)
    }

    /// Compass bearing (0° = north, clockwise) from self to other.
    public func bearing(to other: Coordinate) -> Double {
        let lat1 = latitude  * .pi / 180
        let lat2 = other.latitude  * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let b = atan2(y, x) * 180 / .pi
        return (b + 360).truncatingRemainder(dividingBy: 360)
    }
}

extension CLLocationDistance {
    public var readableDistance: String {
        self < 1000 ? "\(Int(self)) m" : String(format: "%.1f km", self / 1000)
    }
}

extension Date {
    public var relativeShort: String {
        let s = Date().timeIntervalSince(self)
        if s < 60 { return "刚刚" }
        if s < 3600 { return "\(Int(s / 60)) 分钟前" }
        if s < 86_400 { return "\(Int(s / 3600)) 小时前" }
        return "\(Int(s / 86_400)) 天前"
    }
}
