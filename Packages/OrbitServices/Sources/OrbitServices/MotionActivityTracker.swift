import Foundation
import CoreMotion
import OrbitCore

public final class MotionActivityTracker {

    private let manager = CMMotionActivityManager()
    private let available = CMMotionActivityManager.isActivityAvailable()
    private var current: MovementState = .stationary

    public static var isAvailable: Bool { CMMotionActivityManager.isActivityAvailable() }
    public static var authorizationStatus: CMAuthorizationStatus { CMMotionActivityManager.authorizationStatus() }

    public init() {}

    public func start() {
        guard available else { return }
        manager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }
            self.current = Self.map(activity)
        }
    }

    public func stop() {
        guard available else { return }
        manager.stopActivityUpdates()
    }

    public func requestAccess(completion: @escaping (CMAuthorizationStatus) -> Void) {
        guard available else { completion(.restricted); return }
        let end = Date(); let start = end.addingTimeInterval(-3600)
        manager.queryActivityStarting(from: start, to: end, to: .main) { _, _ in
            completion(CMMotionActivityManager.authorizationStatus())
        }
    }

    public func movement(fallbackSpeedKmh speed: Double) -> MovementState {
        guard available else {
            switch speed {
            case ..<1.5:   return .stationary
            case 1.5..<12: return .walking
            case 12..<200: return .driving
            default:       return .flying
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
