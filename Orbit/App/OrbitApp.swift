import SwiftUI
import Foundation
import OrbitCore
import OrbitUI
import OrbitServices

/// App 入口。
///
/// 共享实例统一来自 `AppServices.shared`（与 `AppDelegate` 共用），并把状态中枢、
/// 定位管理器、上报器作为环境对象下发。监听 `scenePhase` 在前后台间切换上报策略。
@main
struct OrbitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var session  = AppServices.shared.session
    @StateObject private var location = AppServices.shared.location
    @StateObject private var reporter = AppServices.shared.reporter
    @StateObject private var langMgr  = LanguageManager.shared

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("orbit_appearance") private var appearance = AppearanceMode.system

    /// 灰度的最终生效值，UI 只读它。
    @AppStorage("orbit_grayscale") private var grayscaleEnabled = false
    /// 服务端下发的灰度开关值（远端通道接入后写入）。
    @AppStorage("orbit_grayscale_remote") private var remoteGrayscale = false
    /// 服务端是否已下发过灰度配置。未下发时走本地日期兜底。
    @AppStorage("orbit_grayscale_remote_set") private var hasRemoteGrayscale = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(location)
                .environmentObject(reporter)
                .environmentObject(langMgr)
                .environment(\.locale, langMgr.current.locale)
                .preferredColorScheme(appearance.scheme)
                // 特殊纪念日全站灰度：整棵 SwiftUI 视图树一层生效（含地图、TabBar、sheet）
                .grayscale(grayscaleEnabled ? 1 : 0)
                .animation(.easeInOut(duration: 0.5), value: grayscaleEnabled)
                .onAppear { refreshGrayscale() }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background: AppServices.shared.reporter.applyBackground(true)
            case .active:
                AppServices.shared.reporter.applyBackground(false)
                refreshGrayscale()
            default: break
            }
        }
    }

    /// 计算灰度的最终生效值。
    /// - 服务端已下发 → 以远端值为准（可开可关）。
    /// - 未下发 → 命中本地兜底日期则开启；未命中时不主动关闭，便于用启动参数手动调试。
    private func refreshGrayscale() {
        if hasRemoteGrayscale {
            if grayscaleEnabled != remoteGrayscale { grayscaleEnabled = remoteGrayscale }
        } else if GrayscalePolicy.isFallbackDay(), !grayscaleEnabled {
            grayscaleEnabled = true
        }
    }

    /// 全站灰度触发策略。嵌在 App 内，避免新增顶层类型（app target 新文件需手动注册 pbxproj）。
    private enum GrayscalePolicy {
        /// 本地兜底纪念日，格式 `MM-dd`；由运营按需维护。留空表示不使用本地兜底。
        /// 服务端下发存在时以 `orbit_grayscale_remote` 为准，此处仅作断网/未接入时的兜底。
        static let fallbackDates: Set<String> = []

        /// 今天是否命中兜底纪念日。
        static func isFallbackDay(_ date: Date = Date()) -> Bool {
            guard !fallbackDates.isEmpty else { return false }
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.dateFormat = "MM-dd"
            return fallbackDates.contains(fmt.string(from: date))
        }
    }
}
