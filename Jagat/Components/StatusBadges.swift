import SwiftUI

// MARK: - 电量徽章
struct BatteryBadge: View {
    let presence: PresenceState
    var compact: Bool = false

    private var iconName: String {
        if presence.isCharging { return "battery.100.bolt" }
        switch presence.batteryLevel {
        case 0..<15:  return "battery.0"
        case 15..<40: return "battery.25"
        case 40..<70: return "battery.50"
        case 70..<90: return "battery.75"
        default:      return "battery.100"
        }
    }

    private var tint: Color {
        if presence.isCharging { return Theme.Palette.mint }
        return presence.isLowBattery ? Theme.Palette.danger : Theme.Palette.subtle
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: iconName)
            if !compact {
                Text("\(presence.batteryLevel)%")
            }
        }
        .font(.system(size: compact ? 11 : 12, weight: .semibold))
        .foregroundStyle(tint)
    }
}

// MARK: - 移动状态胶囊
struct MovementChip: View {
    let presence: PresenceState

    private var tint: Color {
        switch presence.movement {
        case .stationary: return Theme.Palette.subtle
        case .walking:    return Theme.Palette.mint
        case .driving:    return Theme.Palette.sky
        case .flying:     return Theme.Palette.primary
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: presence.movement.systemImage)
            Text(presence.movement.title)
            if presence.movement != .stationary && presence.speedKmh > 0 {
                Text("· \(Int(presence.speedKmh)) km/h")
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(
            Capsule()
                .fill(tint.opacity(0.14))
                .overlay(Capsule().strokeBorder(tint.opacity(0.28), lineWidth: 0.6))
        )
    }
}
