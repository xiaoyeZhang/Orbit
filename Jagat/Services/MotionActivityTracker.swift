import Foundation
import CoreMotion

/// CoreMotion 封装：把系统运动活动（静止/步行/驾车…）映射为 App 的 `MovementState`。
///
/// - 真机可用 CoreMotion；模拟器等不支持时（`isActivityAvailable() == false`）
///   自动用 GPS 速度回退判断，保证总能给出合理状态。
/// - 回调在主队列，`current` 仅在主线程读写。
final class MotionActivityTracker {

    private let manager = CMMotionActivityManager()
    private let available = CMMotionActivityManager.isActivityAvailable()
    private var current: MovementState = .stationary

    /// 设备是否支持运动协处理器。
    static var isAvailable: Bool { CMMotionActivityManager.isActivityAvailable() }

    /// 运动与健身权限状态。
    static var authorizationStatus: CMAuthorizationStatus { CMMotionActivityManager.authorizationStatus() }

    func start() {
        guard available else { return }
        manager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }
            self.current = Self.map(activity)
        }
    }

    func stop() {
        guard available else { return }
        manager.stopActivityUpdates()
    }

    /// 触发系统权限弹窗（首次）。通过一次历史活动查询引导授权，完成后回调最新状态。
    func requestAccess(completion: @escaping (CMAuthorizationStatus) -> Void) {
        guard available else { completion(.restricted); return }
        let end = Date()
        let start = end.addingTimeInterval(-3600)
        manager.queryActivityStarting(from: start, to: end, to: .main) { _, _ in
            completion(CMMotionActivityManager.authorizationStatus())
        }
    }

    /// 当前移动状态。CoreMotion 不可用时按速度（km/h）回退判断。
    func movement(fallbackSpeedKmh speed: Double) -> MovementState {
        guard available else {
            switch speed {
            case ..<1.5: return .stationary
            case 1.5..<12: return .walking
            case 12..<200: return .driving
            default: return .flying
            }
        }
        return current
    }

    private static func map(_ a: CMMotionActivity) -> MovementState {
        if a.automotive { return .driving }
        if a.running || a.walking || a.cycling { return .walking }
        return .stationary
    }
}
