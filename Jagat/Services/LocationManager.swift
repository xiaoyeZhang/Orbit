import Foundation
import CoreLocation
import Combine

/// CoreLocation 封装：权限、前台连续定位、后台/省电的「显著位置变更」，并把每次定位回调出去。
///
/// 不标注 `@MainActor`，以便干净实现 `CLLocationManagerDelegate`（ObjC 协议）。
/// CLLocationManager 在主线程创建，回调即在主线程，`@Published` 更新安全。
final class LocationManager: NSObject, ObservableObject {

    @Published var userCoordinate: Coordinate?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var heading: Double = 0
    @Published var speedKmh: Double = 0

    /// 每次定位更新都会触发（前台连续 / 后台显著变更都会）。
    /// 由 `PresenceReporter` 接管做节流上报。
    var onLocation: ((Coordinate) -> Void)?

    private let manager = CLLocationManager()

    /// 无定位时回退坐标（北京），保证地图有内容。
    var fallbackCoordinate: Coordinate { SampleData.cityCenter }
    var effectiveCoordinate: Coordinate { userCoordinate ?? fallbackCoordinate }

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 20
        manager.pausesLocationUpdatesAutomatically = false
    }

    // MARK: - 权限
    func requestPermission() { manager.requestWhenInUseAuthorization() }
    /// 申请「始终」权限（后台/被关闭后上传位置所必需）。
    func requestAlwaysPermission() { manager.requestAlwaysAuthorization() }

    // MARK: - 启停
    /// 前台连续定位（高精度）。
    func start() { startContinuous() }

    func startContinuous() {
        enableBackgroundIfAuthorized()
        manager.stopMonitoringSignificantLocationChanges()
        manager.startUpdatingLocation()
    }

    /// 省电：显著位置变更（约 500m / 基站切换触发），可在后台、甚至 App 被系统终止后唤醒。
    func startSignificantChanges() {
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else {
            startContinuous(); return
        }
        enableBackgroundIfAuthorized()
        manager.stopUpdatingLocation()
        manager.startMonitoringSignificantLocationChanges()
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
    }

    /// 允许后台定位（需 Info.plist 含 UIBackgroundModes=location，本工程已配置）。
    private func enableBackgroundIfAuthorized() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.allowsBackgroundLocationUpdates = true
        default:
            break
        }
        manager.pausesLocationUpdatesAutomatically = false
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            enableBackgroundIfAuthorized()
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let coord = Coordinate(loc.coordinate)
        userCoordinate = coord
        speedKmh = loc.speed >= 0 ? loc.speed * 3.6 : 0
        onLocation?(coord)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 定位失败时静默回退，UI 仍可用 effectiveCoordinate。
    }
}
