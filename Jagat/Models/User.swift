import Foundation

/// 当前登录用户的资料。
struct UserProfile: Codable, Equatable, Identifiable {
    var id: String
    var displayName: String
    var bio: String
    var avatar: AvatarConfig
    var inviteCode: String        // 给别人添加自己用的邀请码
    var phoneNumber: String?

    static let placeholder = UserProfile(
        id: "me",
        displayName: "我",
        bio: "在路上 🚀",
        avatar: .default,
        inviteCode: "JAGAT-ME01",
        phoneNumber: nil
    )
}

/// 设备 / 状态信息（电量、移动等），好友与自己共用。
struct PresenceState: Codable, Equatable, Hashable {
    var batteryLevel: Int          // 0...100
    var isCharging: Bool
    var movement: MovementState
    var speedKmh: Double

    static let unknown = PresenceState(batteryLevel: 100, isCharging: false, movement: .stationary, speedKmh: 0)

    var isLowBattery: Bool { batteryLevel <= 20 && !isCharging }
}

enum MovementState: String, Codable, Equatable, Hashable {
    case stationary    // 静止
    case walking       // 步行
    case driving       // 驾车
    case flying        // 飞行

    var title: String {
        switch self {
        case .stationary: return "静止"
        case .walking: return "步行中"
        case .driving: return "驾车中"
        case .flying: return "飞行中"
        }
    }

    var systemImage: String {
        switch self {
        case .stationary: return "figure.stand"
        case .walking: return "figure.walk"
        case .driving: return "car.fill"
        case .flying: return "airplane"
        }
    }
}
