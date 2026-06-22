import Foundation

public enum ReportingKey {
    public static let minInterval      = "reporting.minIntervalSeconds"
    public static let minDistance      = "reporting.minDistanceMeters"
    public static let presenceInterval = "reporting.presenceIntervalSeconds"
    public static let powerSaving      = "reporting.powerSaving"
    public static let backgroundUpload = "reporting.backgroundUpload"
}

public enum ReportingDefaults {
    public static func register() {
        UserDefaults.standard.register(defaults: [
            ReportingKey.minInterval:      10.0,
            ReportingKey.minDistance:      25.0,
            ReportingKey.presenceInterval: 30.0,
            ReportingKey.powerSaving:      true,
            ReportingKey.backgroundUpload: true,
        ])
    }
}

public struct ReportingConfig {
    public var minInterval: TimeInterval
    public var minDistance: Double
    public var presenceInterval: TimeInterval
    public var powerSaving: Bool
    public var backgroundUpload: Bool

    public static var current: ReportingConfig {
        let d = UserDefaults.standard
        return ReportingConfig(
            minInterval:      max(1, d.double(forKey: ReportingKey.minInterval)),
            minDistance:      max(0, d.double(forKey: ReportingKey.minDistance)),
            presenceInterval: max(5, d.double(forKey: ReportingKey.presenceInterval)),
            powerSaving:      d.bool(forKey: ReportingKey.powerSaving),
            backgroundUpload: d.bool(forKey: ReportingKey.backgroundUpload)
        )
    }
}
