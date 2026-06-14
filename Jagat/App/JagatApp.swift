import SwiftUI

/// App 入口。
///
/// 共享实例统一来自 `AppServices.shared`（与 `AppDelegate` 共用），并把状态中枢、
/// 定位管理器、上报器作为环境对象下发。监听 `scenePhase` 在前后台间切换上报策略。
@main
struct JagatApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var session = AppServices.shared.session
    @StateObject private var location = AppServices.shared.location
    @StateObject private var reporter = AppServices.shared.reporter

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(location)
                .environmentObject(reporter)
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background: AppServices.shared.reporter.applyBackground(true)
            case .active:     AppServices.shared.reporter.applyBackground(false)
            default: break
            }
        }
    }
}
