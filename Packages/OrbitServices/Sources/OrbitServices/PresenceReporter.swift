import Foundation
import CoreLocation
import OrbitCore
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class PresenceReporter: ObservableObject {

    @Published public private(set) var lastReportedAt: Date?
    @Published public private(set) var currentPresence: PresenceState = .unknown

    private let backend: BackendService
    private let location: LocationManager
    private let motion = MotionActivityTracker()

    private var started = false
    private var lastSentCoord: Coordinate?
    private var lastSentAt = Date.distantPast
    private var lastPresence: PresenceState?
    private var lastPresenceAt = Date.distantPast
    private var presenceLoop: Task<Void, Never>?

    public init(backend: BackendService, location: LocationManager) {
        self.backend = backend; self.location = location
    }

    public func start() {
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

    public func stop() {
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

    public func startForBackgroundRelaunch() {
        ReportingDefaults.register()
        guard ReportingConfig.current.backgroundUpload else { return }
        bindLocation()
        location.startSignificantChanges()
    }

    public func applyBackground(_ background: Bool) {
        guard started else { return }
        let cfg = ReportingConfig.current
        if background {
            if cfg.backgroundUpload {
                cfg.powerSaving ? location.startSignificantChanges() : location.startContinuous()
            } else { location.stop() }
            presenceLoop?.cancel(); presenceLoop = nil
        } else {
            location.startContinuous()
            startPresenceLoop()
        }
    }

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
        lastSentCoord = coord; lastSentAt = now
        #if canImport(UIKit)
        let bgTask = UIApplication.shared.beginBackgroundTask(withName: "orbit.location.upload")
        #endif
        Task { @MainActor in
            try? await backend.updateMyLocation(coord)
            lastReportedAt = Date()
            #if canImport(UIKit)
            if bgTask != .invalid { UIApplication.shared.endBackgroundTask(bgTask) }
            #endif
        }
    }

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
            lastPresence = presence; lastPresenceAt = Date()
            Task { @MainActor in try? await backend.updatePresence(presence) }
        }
    }

    private func collectPresence() -> PresenceState {
        var battery = 100; var charging = false
        #if canImport(UIKit)
        let level = UIDevice.current.batteryLevel
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
