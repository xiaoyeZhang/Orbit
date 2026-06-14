import Foundation
import CoreLocation

/// 可编码的经纬度坐标（CLLocationCoordinate2D 本身不可 Codable / Equatable）。
struct Coordinate: Codable, Equatable, Hashable {
    var latitude: Double
    var longitude: Double

    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ c: CLLocationCoordinate2D) {
        self.latitude = c.latitude
        self.longitude = c.longitude
    }

    /// 两点间距离（米）。
    func distance(to other: Coordinate) -> CLLocationDistance {
        clLocation.distance(from: other.clLocation)
    }
}

extension CLLocationDistance {
    /// 人类可读距离："120 m" / "1.4 km"。
    var readableDistance: String {
        if self < 1000 {
            return "\(Int(self)) m"
        }
        return String(format: "%.1f km", self / 1000)
    }
}

extension Date {
    /// 相对时间："刚刚" / "5 分钟前" / "2 小时前"。
    var relativeShort: String {
        let seconds = Date().timeIntervalSince(self)
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(Int(seconds / 60)) 分钟前" }
        if seconds < 86_400 { return "\(Int(seconds / 3600)) 小时前" }
        return "\(Int(seconds / 86_400)) 天前"
    }
}
