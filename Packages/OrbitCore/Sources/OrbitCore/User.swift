import Foundation

public struct UserProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var displayName: String
    public var bio: String
    public var avatar: AvatarConfig
    public var inviteCode: String
    public var phoneNumber: String?

    public init(id: String, displayName: String, bio: String,
                avatar: AvatarConfig, inviteCode: String, phoneNumber: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.bio = bio
        self.avatar = avatar
        self.inviteCode = inviteCode
        self.phoneNumber = phoneNumber
    }

    public static let placeholder = UserProfile(
        id: "me", displayName: "我", bio: "在路上 🚀",
        avatar: .default, inviteCode: "ORBIT-ME01"
    )
}

public struct PresenceState: Codable, Equatable, Hashable, Sendable {
    public var batteryLevel: Int
    public var isCharging: Bool
    public var movement: MovementState
    public var speedKmh: Double

    public init(batteryLevel: Int, isCharging: Bool, movement: MovementState, speedKmh: Double) {
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
        self.movement = movement
        self.speedKmh = speedKmh
    }

    public static let unknown = PresenceState(batteryLevel: 100, isCharging: false,
                                               movement: .stationary, speedKmh: 0)
    public var isLowBattery: Bool { batteryLevel <= 20 && !isCharging }
}

public enum MovementState: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case stationary, walking, driving, flying

    public var title: String {
        switch self {
        case .stationary: return "静止"
        case .walking:    return "步行中"
        case .driving:    return "驾车中"
        case .flying:     return "飞行中"
        }
    }
    public var systemImage: String {
        switch self {
        case .stationary: return "figure.stand"
        case .walking:    return "figure.walk"
        case .driving:    return "car.fill"
        case .flying:     return "airplane"
        }
    }
}
