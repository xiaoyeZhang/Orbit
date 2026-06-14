import Foundation

/// 位置/状态上报的可配置项（持久化在 UserDefaults）。
/// - UI 端用 `@AppStorage(ReportingKey.xxx)` 双向绑定。
/// - 上报器用 `ReportingConfig.current` 读取当前值（改动即时生效）。
enum ReportingKey {
    static let minInterval = "reporting.minIntervalSeconds"     // 位置最小上报间隔（秒）
    static let minDistance = "reporting.minDistanceMeters"      // 触发立即上报的位移阈值（米）
    static let presenceInterval = "reporting.presenceIntervalSeconds" // 状态上报间隔（秒）
    static let powerSaving = "reporting.powerSaving"            // 后台改用显著位置变更
    static let backgroundUpload = "reporting.backgroundUpload" // 应用进入后台/被关闭后仍上传
}

enum ReportingDefaults {
    /// 注册默认值（多次调用安全）。在 App 启动尽早调用。
    static func register() {
        UserDefaults.standard.register(defaults: [
            ReportingKey.minInterval: 10.0,
            ReportingKey.minDistance: 25.0,
            ReportingKey.presenceInterval: 30.0,
            ReportingKey.powerSaving: true,
            ReportingKey.backgroundUpload: true,
        ])
    }
}

/// 供上报器读取的配置快照。
struct ReportingConfig {
    var minInterval: TimeInterval
    var minDistance: Double
    var presenceInterval: TimeInterval
    var powerSaving: Bool
    var backgroundUpload: Bool

    static var current: ReportingConfig {
        let d = UserDefaults.standard
        return ReportingConfig(
            minInterval: max(1, d.double(forKey: ReportingKey.minInterval)),
            minDistance: max(0, d.double(forKey: ReportingKey.minDistance)),
            presenceInterval: max(5, d.double(forKey: ReportingKey.presenceInterval)),
            powerSaving: d.bool(forKey: ReportingKey.powerSaving),
            backgroundUpload: d.bool(forKey: ReportingKey.backgroundUpload)
        )
    }
}
