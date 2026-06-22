import Foundation
import OrbitCore
import OrbitUI
import OrbitServices

/// 全局环境配置。
///
/// 切换数据来源的唯一开关就在这里：
/// - 演示 / 离线：返回 `MockBackendService()`
/// - 接入真实后端：把下面改成 `LiveBackendService(baseURL: ...)`，其余代码无需改动。
@MainActor
enum AppEnvironment {

    /// 后端来源。切换它即可在「本地 Mock / Firebase 实时 / 自定义 REST」之间选择。
    enum BackendKind { case mock, firebase, rest }

    /// ⬇️ 改这一行即可切换后端。接入 Firebase 见 FIREBASE_SETUP.md。
    static let backendKind: BackendKind = .mock

    /// 自定义 REST 后端地址（backendKind == .rest 时使用）。
    static let liveBaseURL = URL(string: "https://api.example.com")!

    static func makeBackend() -> BackendService {
        switch backendKind {
        case .mock:
            return MockBackendService()
        case .firebase:
            #if ORBIT_FIREBASE
            return FirebaseBackendService()
            #else
            assertionFailure("未集成 Firebase SDK：请按 FIREBASE_SETUP.md，用 ENABLE_FIREBASE=1 重新生成工程")
            return MockBackendService()
            #endif
        case .rest:
            return LiveBackendService(baseURL: liveBaseURL)
        }
    }
}

/// 进程内共享的后端实例持有者。
///
/// 在 `JagatApp.init` 中赋值，供那些不便从环境注入处获取后端的视图
/// （如在初始化器里就要建 ViewModel 的 `ChatView`）使用。
@MainActor
enum SharedBackend {
    static var current: BackendService!
}
