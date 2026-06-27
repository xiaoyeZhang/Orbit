import UIKit
import OrbitCore
import OrbitUI
import OrbitServices

/// 处理 App 生命周期里 SwiftUI 不便覆盖的部分——尤其是被「显著位置变更」唤醒的冷启动。
///
/// 当 App 因位置事件被系统重新拉起（哪怕此前已被终止）时，`launchOptions` 含
/// `.location`，此时恢复定位监听并继续上报，实现「应用关闭后仍上传定位」。
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // 让 ScrollView 内的 Button 立即响应按压，不等待滚动判断
        UIScrollView.appearance().delaysContentTouches = false
        ReportingDefaults.register()

        if launchOptions?[.location] != nil {
            // 被显著位置变更唤醒（App 可能已被系统终止）→ 后台恢复定位上报
            Task { @MainActor in
                AppServices.shared.reporter.startForBackgroundRelaunch()
            }
        }
        return true
    }
}
