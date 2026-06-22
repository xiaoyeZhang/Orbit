import Foundation
import CoreLocation
import Combine
import OrbitCore

public final class LocationManager: NSObject, ObservableObject {

    @Published public var userCoordinate: Coordinate?
    @Published public var authorizationStatus: CLAuthorizationStatus
    @Published public var heading: Double = 0
    @Published public var speedKmh: Double = 0

    public var onLocation: ((Coordinate) -> Void)?

    private let manager = CLLocationManager()

    public var fallbackCoordinate: Coordinate { SampleData.cityCenter }
    public var effectiveCoordinate: Coordinate { userCoordinate ?? fallbackCoordinate }

    public override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 20
        manager.pausesLocationUpdatesAutomatically = false
    }

    public func requestPermission() { manager.requestWhenInUseAuthorization() }
    public func requestAlwaysPermission() { manager.requestAlwaysAuthorization() }

    public func start() { startContinuous() }

    public func startContinuous() {
        enableBackgroundIfAuthorized()
        manager.stopMonitoringSignificantLocationChanges()
        manager.startUpdatingLocation()
    }

    public func startSignificantChanges() {
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else {
            startContinuous(); return
        }
        enableBackgroundIfAuthorized()
        manager.stopUpdatingLocation()
        manager.startMonitoringSignificantLocationChanges()
    }

    public func stop() {
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
    }

    private func enableBackgroundIfAuthorized() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.allowsBackgroundLocationUpdates = true
        default: break
        }
        manager.pausesLocationUpdatesAutomatically = false
    }
}

extension LocationManager: CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            enableBackgroundIfAuthorized()
            manager.startUpdatingLocation()
        default: break
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let coord = Coordinate(loc.coordinate)
        userCoordinate = coord
        speedKmh = loc.speed >= 0 ? loc.speed * 3.6 : 0
        onLocation?(coord)
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
