import Foundation
import OrbitCore
import OrbitUI
import OrbitServices

/// 进程内共享服务容器。
///
/// 让 `AppDelegate`（处理后台/被关闭后唤醒）与 SwiftUI 视图共用同一批实例：
/// 后端、定位、会话、上报器。后台被「显著位置变更」唤醒时，AppDelegate 通过它恢复上报。
@MainActor
final class AppServices {
    static let shared = AppServices()

    let backend: BackendService
    let location: LocationManager
    let session: SessionStore
    let reporter: PresenceReporter

    private init() {
        ReportingDefaults.register()
        let backend = AppEnvironment.makeBackend()
        SharedBackend.current = backend
        self.backend = backend
        let loc = LocationManager()
        self.location = loc
        self.session = SessionStore(backend: backend)
        self.reporter = PresenceReporter(backend: backend, location: loc)
    }
}
