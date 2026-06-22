import SwiftUI
import OrbitCore

// OrbitCore 的纯数据枚举 → SwiftUI Color / LinearGradient
extension AvatarConfig.SkinTone {
    public var color: Color {
        switch self {
        case .light:  return Color(hex: 0xFFE0BD)
        case .medium: return Color(hex: 0xF1C27D)
        case .tan:    return Color(hex: 0xC68642)
        case .deep:   return Color(hex: 0x8D5524)
        }
    }
}

extension AvatarConfig.HairColor {
    public var color: Color {
        switch self {
        case .black:  return Color(hex: 0x2B2B2B)
        case .brown:  return Color(hex: 0x6B4226)
        case .blonde: return Color(hex: 0xE0B04A)
        case .pink:   return Color(hex: 0xFF7AA2)
        }
    }
}

extension AvatarConfig.BackgroundStyle {
    public var gradient: LinearGradient {
        let colors: [Color]
        switch self {
        case .violet:    colors = [Color(hex: 0x6C5CE7), Color(hex: 0xA29BFE)]
        case .sky:       colors = [Color(hex: 0x54A0FF), Color(hex: 0x00D2A8)]
        case .mint:      colors = [Color(hex: 0x00D2A8), Color(hex: 0x55EFC4)]
        case .sunshine:  colors = [Color(hex: 0xFDCB6E), Color(hex: 0xFFA801)]
        case .pink:      colors = [Color(hex: 0xFD79A8), Color(hex: 0xFF6B6B)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
