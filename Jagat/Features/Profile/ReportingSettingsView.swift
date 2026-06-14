import SwiftUI
import CoreLocation
import CoreMotion
#if canImport(UIKit)
import UIKit
#endif

/// 「上报与隐私」设置：可调上报频率/阈值、省电与后台上传开关、定位与运动权限引导。
struct ReportingSettingsView: View {
    @EnvironmentObject private var location: LocationManager
    @Environment(\.dismiss) private var dismiss

    @AppStorage(ReportingKey.minInterval) private var minInterval: Double = 10
    @AppStorage(ReportingKey.minDistance) private var minDistance: Double = 25
    @AppStorage(ReportingKey.presenceInterval) private var presenceInterval: Double = 30
    @AppStorage(ReportingKey.powerSaving) private var powerSaving: Bool = true
    @AppStorage(ReportingKey.backgroundUpload) private var backgroundUpload: Bool = true

    @State private var motionStatus = MotionActivityTracker.authorizationStatus
    private let motion = MotionActivityTracker()

    var body: some View {
        NavigationStack {
            Form {
                // 上报频率
                Section {
                    stepperRow("最小上报间隔", value: $minInterval, range: 5...120, step: 5, unit: "秒")
                    stepperRow("最小位移阈值", value: $minDistance, range: 10...500, step: 5, unit: "米")
                    stepperRow("状态上报间隔", value: $presenceInterval, range: 10...300, step: 10, unit: "秒")
                } header: {
                    Text("上报频率")
                } footer: {
                    Text("移动超过「位移阈值」会立即上报；否则最多每「上报间隔」一次，静止时不刷接口。")
                }

                // 省电与后台
                Section {
                    Toggle("省电模式（显著位置变更）", isOn: $powerSaving)
                    Toggle("应用关闭后仍上传位置", isOn: $backgroundUpload)
                        .onChange(of: backgroundUpload) { on in
                            if on { location.requestAlwaysPermission() }
                        }
                } header: {
                    Text("省电与后台")
                } footer: {
                    Text("省电模式：进入后台后改用「显著位置变更」（约每 500 米触发），更省电。\n应用关闭后仍上传：被系统终止后，位置显著变化会唤醒 App 继续上传——需授予「始终」定位权限。")
                }

                // 定位权限
                Section("定位权限") {
                    statusRow(title: "当前状态", value: locationStatusText, ok: isLocationAlways)
                    Button("请求「始终」定位权限") { location.requestAlwaysPermission() }
                    Button("打开系统设置") { openSystemSettings() }
                }

                // 运动与健身权限
                Section {
                    statusRow(title: "当前状态", value: motionStatusText, ok: motionStatus == .authorized)
                    Button("请求运动与健身权限") {
                        motion.requestAccess { status in motionStatus = status }
                    }
                    .disabled(!MotionActivityTracker.isAvailable)
                } header: {
                    Text("运动与健身权限")
                } footer: {
                    Text(MotionActivityTracker.isAvailable
                         ? "用于识别步行/驾车等移动状态展示给好友。"
                         : "本设备/模拟器不支持运动协处理器，将用 GPS 速度估算移动状态。")
                }
            }
            .navigationTitle("上报与隐私")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    // MARK: - 小部件
    private func stepperRow(_ title: String, value: Binding<Double>,
                            range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue)) \(unit)")
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func statusRow(title: String, value: String, ok: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(ok ? Theme.Palette.mint : Theme.Palette.subtle)
                    .frame(width: 8, height: 8)
                Text(value).foregroundColor(.secondary)
            }
        }
    }

    private var isLocationAlways: Bool { location.authorizationStatus == .authorizedAlways }

    private var locationStatusText: String {
        switch location.authorizationStatus {
        case .authorizedAlways: return "始终"
        case .authorizedWhenInUse: return "使用期间"
        case .denied: return "已拒绝"
        case .restricted: return "受限"
        case .notDetermined: return "未决定"
        @unknown default: return "未知"
        }
    }

    private var motionStatusText: String {
        switch motionStatus {
        case .authorized: return "已授权"
        case .denied: return "已拒绝"
        case .restricted: return "受限/不可用"
        case .notDetermined: return "未决定"
        @unknown default: return "未知"
        }
    }

    private func openSystemSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
