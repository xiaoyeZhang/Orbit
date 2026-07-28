import Foundation
import SwiftUI
import CoreLocation
import OrbitCore

// MARK: - 氛围地图：天气 / 昼夜 / 季节 的氛围状态模型
// 纯自有实现，用于把位置周边的"氛围"叠到地图上，
// 并让异地好友的当地时间/天气可见，形成跨距离的情感连接。

/// 一天中的时段（由当地时间推算，离线可用）
public enum TimeOfDay: String, Codable, Equatable, Sendable {
    case dawn, day, dusk, night

    public var title: String {
        switch self {
        case .dawn:  return "黎明"
        case .day:   return "白天"
        case .dusk:  return "黄昏"
        case .night: return "夜晚"
        }
    }
    public var systemImage: String {
        switch self {
        case .dawn:  return "sun.horizon.fill"
        case .day:   return "sun.max.fill"
        case .dusk:  return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }
    /// 地图叠层用的淡色调
    public var tint: Color { AmbientPalette.color(for: self) }
    public var overlayOpacity: Double {
        switch self {
        case .day:   return 0.10
        case .dawn, .dusk: return 0.15
        case .night: return 0.28
        }
    }
}

/// 季节（由月份 + 半球推算）
public enum Season: String, Codable, Equatable, Sendable {
    case spring, summer, autumn, winter

    public var title: String {
        switch self {
        case .spring: return "春"
        case .summer: return "夏"
        case .autumn: return "秋"
        case .winter: return "冬"
        }
    }
    public var systemImage: String {
        switch self {
        case .spring: return "leaf.fill"
        case .summer: return "sun.max.fill"
        case .autumn: return "wind"
        case .winter: return "snowflake"
        }
    }
    public var tint: Color { AmbientPalette.color(for: self) }
    public var overlayOpacity: Double { 0.12 }

    public var opposite: Season {
        switch self {
        case .spring: return .autumn
        case .summer: return .winter
        case .autumn: return .spring
        case .winter: return .summer
        }
    }
}

/// 天气状况（来自 open-meteo 的 WMO weather_code）
public enum WeatherCondition: String, Codable, Equatable, Sendable {
    case clear, cloudy, fog, rain, snow, thunder, unknown

    public var title: String {
        switch self {
        case .clear:   return "晴"
        case .cloudy:  return "多云"
        case .fog:     return "雾"
        case .rain:    return "雨"
        case .snow:    return "雪"
        case .thunder: return "雷暴"
        case .unknown: return "—"
        }
    }
    public var systemImage: String {
        switch self {
        case .clear:   return "sun.max.fill"
        case .cloudy:  return "cloud.fill"
        case .fog:     return "cloud.fog.fill"
        case .rain:    return "cloud.rain.fill"
        case .snow:    return "cloud.snow.fill"
        case .thunder: return "cloud.bolt.fill"
        case .unknown: return "cloud.fill"
        }
    }
    public var tint: Color { AmbientPalette.color(for: self) }
    public var overlayOpacity: Double { 0.10 }

    public init(wmoCode: Int) {
        switch wmoCode {
        case 0, 1:             self = .clear
        case 2, 3:             self = .cloudy
        case 45, 48:           self = .fog
        case 51...67, 80...82: self = .rain
        case 71...77, 85...86: self = .snow
        case 95...99:          self = .thunder
        default:               self = .unknown
        }
    }
}

/// 半球
public enum Hemisphere: String, Codable, Equatable, Sendable {
    case north, south
}

/// 可开关的氛围图层
public struct AmbientLayers: Equatable, Sendable {
    public var dayNight: Bool
    public var weather: Bool
    public var season: Bool
    public init(dayNight: Bool = true, weather: Bool = true, season: Bool = true) {
        self.dayNight = dayNight
        self.weather = weather
        self.season = season
    }
}

/// 某一坐标/时刻的氛围快照（用于地图叠层与文案）
public struct AmbientState {
    public let timeOfDay: TimeOfDay
    public let season: Season
    public let weather: WeatherCondition
    public let place: String

    public init(timeOfDay: TimeOfDay, season: Season, weather: WeatherCondition, place: String) {
        self.timeOfDay = timeOfDay
        self.season = season
        self.weather = weather
        self.place = place
    }

    public var summary: String { "\(place) · \(weather.title) · \(timeOfDay.title)" }
}

// MARK: - 颜色集中管理（避免依赖 OrbitUI 的 Color(hex:)）
private enum AmbientPalette {
    static func color(for t: TimeOfDay) -> Color {
        switch t {
        case .dawn:  return rgb(255, 184, 119)
        case .day:   return rgb(159, 210, 255)
        case .dusk:  return rgb(255, 140, 90)
        case .night: return rgb(42, 42, 85)
        }
    }
    static func color(for s: Season) -> Color {
        switch s {
        case .spring: return rgb(168, 230, 161)
        case .summer: return rgb(255, 224, 138)
        case .autumn: return rgb(255, 176, 102)
        case .winter: return rgb(191, 216, 255)
        }
    }
    static func color(for w: WeatherCondition) -> Color {
        switch w {
        case .clear:   return rgb(255, 224, 138)
        case .cloudy:  return rgb(200, 206, 214)
        case .fog:     return rgb(216, 220, 224)
        case .rain:    return rgb(127, 168, 216)
        case .snow:    return rgb(207, 224, 245)
        case .thunder: return rgb(154, 160, 224)
        case .unknown: return rgb(200, 206, 214)
        }
    }
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> Color {
        Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

// MARK: - 本地时间推算（按经度近似，离线可用）—— 异地氛围同步的核心
extension Coordinate {
    /// 由经度近似的 UTC 偏移（小时）：每 15° 约 1 小时
    public var approximateUTCOffset: Double { (longitude / 15.0).rounded() }

    public var hemisphere: Hemisphere { latitude >= 0 ? .north : .south }

    /// 该坐标处的本地小时（0..<24），基于经度近似时区
    public func localHour(at date: Date = Date()) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let utcHour = cal.component(.hour, from: date)
        let utcMin  = cal.component(.minute, from: date)
        let frac = Double(utcHour) + Double(utcMin) / 60.0 + approximateUTCOffset
        let h = Int((frac.truncatingRemainder(dividingBy: 24) + 24).truncatingRemainder(dividingBy: 24))
        return h
    }

    /// 该坐标处的本地小时（便捷访问）
    public var localHour: Int { localHour(at: Date()) }

    public func localTimeOfDay(at date: Date = Date()) -> TimeOfDay {
        switch localHour(at: date) {
        case 5..<8:   return .dawn
        case 8..<18:  return .day
        case 18..<20: return .dusk
        default:      return .night
        }
    }

    public var localTimeOfDay: TimeOfDay { localTimeOfDay() }
}

extension Season {
    public static func current(for coordinate: Coordinate, at date: Date = Date()) -> Season {
        let month = Calendar.current.component(.month, from: date)
        let northern: Season
        switch month {
        case 3...5:    northern = .spring
        case 6...8:    northern = .summer
        case 9...11:   northern = .autumn
        default:       northern = .winter
        }
        return coordinate.hemisphere == .north ? northern : northern.opposite
    }
}

// MARK: - 天气代码抓取（open-meteo）
/// 抓取某坐标的 WMO 天气代码，返回 nil 表示失败
public func fetchWeatherCode(for coord: Coordinate) async -> Int? {
    let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(coord.latitude)&longitude=\(coord.longitude)&current=weather_code"
    guard let url = URL(string: urlStr),
          let (data, _) = try? await URLSession.shared.data(from: url),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let current = json["current"] as? [String: Any],
          let code = current["weather_code"] as? Int else { return nil }
    return code
}
