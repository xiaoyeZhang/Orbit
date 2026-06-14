import Foundation
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

/// 把「我的实时状态」节流上报到后端，支持省电与后台/被关闭后上传。
///
/// - **位置**：事件驱动（`LocationManager.onLocation`），按「距离 + 时间」双阈值节流；
///   上报包在后台任务断言里，确保被显著位置变更唤醒时也能完成上传。
/// - **状态**：前台周期采集电量（UIDevice）+ 移动（CoreMotion）+ 速度，变化或到期才上报。
/// - **前后台**：进入后台时，按设置切换为「显著位置变更」（省电）或停止；回到前台恢复连续定位。
/// - 所有阈值/开关来自 `ReportingConfig.current`（用户可在「上报与隐私」里实时调整）。
///
/// 后端为 Mock / 未对接时，上报方法为空操作，运行无副作用。
@MainActor
final class PresenceReporter: ObservableObject {

    @Published private(set) var lastReportedAt: Date?
    @Published private(set) var currentPresence: PresenceState = .unknown

    private let backend: BackendService
    private let location: LocationManager
    private let motion = MotionActivityTracker()

    private var started = false
    private var lastSentCoord: Coordinate?
    private var lastSentAt = Date.distantPast
    private var lastPresence: PresenceState?
    private var lastPresenceAt = Date.distantPast
    private var presenceLoop: Task<Void, Never>?

    init(backend: BackendService, location: LocationManager) {
        self.backend = backend
        self.location = location
    }

    // MARK: - 启停（登录后进入主界面）
    func start() {
        guard !started else { return }
        started = true
        ReportingDefaults.register()
        let cfg = ReportingConfig.current

        location.requestPermission()
        if cfg.backgroundUpload { location.requestAlwaysPermission() }
        bindLocation()

        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        #endif
        motion.start()
        location.startContinuous()
        startPresenceLoop()
    }

    func stop() {
        guard started else { return }
        started = false
        presenceLoop?.cancel(); presenceLoop = nil
        motion.stop()
        location.onLocation = nil
        location.stop()
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = false
        #endif
    }

    /// 被「显著位置变更」唤醒（App 可能已被系统终止）时调用：后台恢复定位上报。
    func startForBackgroundRelaunch() {
        ReportingDefaults.register()
        guard ReportingConfig.current.backgroundUpload else { return }
        bindLocation()
        location.startSignificantChanges()
    }

    // MARK: - 前后台切换
    func applyBackground(_ background: Bool) {
        guard started else { return }
        let cfg = ReportingConfig.current
        if background {
            if cfg.backgroundUpload {
                if cfg.powerSaving { location.startSignificantChanges() }   // 省电
                else { location.startContinuous() }                          // 后台连续（更耗电）
            } else {
                location.stop()                                              // 不允许后台上传：进入后台即停
            }
            presenceLoop?.cancel(); presenceLoop = nil
        } else {
            location.startContinuous()
            startPresenceLoop()
        }
    }

    // MARK: - 位置上报（前台 + 后台共用）
    private func bindLocation() {
        location.onLocation = { [weak self] coord in
            Task { @MainActor in self?.handleLocation(coord) }
        }
    }

    private func handleLocation(_ coord: Coordinate) {
        let cfg = ReportingConfig.current
        let now = Date()
        let moved = lastSentCoord.map { coord.distance(to: $0) } ?? .greatestFiniteMagnitude
        let dueByTime = now.timeIntervalSince(lastSentAt) >= cfg.minInterval
        guard moved >= cfg.minDistance || (dueByTime && moved >= 1) else { return }
        lastSentCoord = coord
        lastSentAt = now

        #if canImport(UIKit)
        // 后台任务断言：确保被唤醒后短暂运行时间里能完成上传。
        let bgTask = UIApplication.shared.beginBackgroundTask(withName: "jagat.location.upload")
        #endif
        Task { @MainActor in
            try? await backend.updateMyLocation(coord)
            lastReportedAt = Date()
            #if canImport(UIKit)
            if bgTask != .invalid { UIApplication.shared.endBackgroundTask(bgTask) }
            #endif
        }
    }

    // MARK: - 状态周期采集（前台）
    private func startPresenceLoop() {
        presenceLoop?.cancel()
        presenceLoop = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.collectAndReportPresence()
                let interval = ReportingConfig.current.presenceInterval
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    private func collectAndReportPresence() {
        let presence = collectPresence()
        currentPresence = presence
        if presence != lastPresence {
            lastPresence = presence
            lastPresenceAt = Date()
            Task { @MainActor in try? await backend.updatePresence(presence) }
        }
    }

    private func collectPresence() -> PresenceState {
        var battery = 100
        var charging = false
        #if canImport(UIKit)
        let level = UIDevice.current.batteryLevel        // 0...1，未知为 -1
        if level >= 0 { battery = Int((level * 100).rounded()) }
        switch UIDevice.current.batteryState {
        case .charging, .full: charging = true
        default: charging = false
        }
        #endif
        let speed = max(0, location.speedKmh)
        let movement = motion.movement(fallbackSpeedKmh: speed)
        return PresenceState(batteryLevel: battery, isCharging: charging,
                             movement: movement, speedKmh: speed)
    }
}
