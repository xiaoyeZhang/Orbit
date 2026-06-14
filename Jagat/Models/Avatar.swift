import SwiftUI

/// 头像配置。完全由代码绘制（无外部素材），可在「头像编辑器」里自定义。
struct AvatarConfig: Codable, Equatable, Hashable {
    var skinTone: SkinTone = .medium
    var hair: HairStyle = .short
    var hairColor: HairColor = .brown
    var accessory: Accessory = .none
    var background: BackgroundStyle = .violet

    enum SkinTone: String, Codable, CaseIterable, Identifiable {
        case light, medium, tan, deep
        var id: String { rawValue }
        var color: Color {
            switch self {
            case .light: return Color(hex: 0xFFE0BD)
            case .medium: return Color(hex: 0xF1C27D)
            case .tan: return Color(hex: 0xC68642)
            case .deep: return Color(hex: 0x8D5524)
            }
        }
        var title: String {
            switch self {
            case .light: return "白皙"
            case .medium: return "自然"
            case .tan: return "小麦"
            case .deep: return "深邃"
            }
        }
    }

    enum HairStyle: String, Codable, CaseIterable, Identifiable {
        case short, long, bun, bald
        var id: String { rawValue }
        var title: String {
            switch self {
            case .short: return "短发"
            case .long: return "长发"
            case .bun: return "丸子头"
            case .bald: return "光头"
            }
        }
    }

    enum HairColor: String, Codable, CaseIterable, Identifiable {
        case black, brown, blonde, pink
        var id: String { rawValue }
        var color: Color {
            switch self {
            case .black: return Color(hex: 0x2B2B2B)
            case .brown: return Color(hex: 0x6B4226)
            case .blonde: return Color(hex: 0xE0B04A)
            case .pink: return Color(hex: 0xFF7AA2)
            }
        }
        var title: String {
            switch self {
            case .black: return "黑色"
            case .brown: return "棕色"
            case .blonde: return "金色"
            case .pink: return "粉色"
            }
        }
    }

    enum Accessory: String, Codable, CaseIterable, Identifiable {
        case none, glasses, cap
        var id: String { rawValue }
        var title: String {
            switch self {
            case .none: return "无"
            case .glasses: return "眼镜"
            case .cap: return "帽子"
            }
        }
    }

    enum BackgroundStyle: String, Codable, CaseIterable, Identifiable {
        case violet, sky, mint, sunshine, pink
        var id: String { rawValue }
        var gradient: LinearGradient {
            let colors: [Color]
            switch self {
            case .violet: colors = [Color(hex: 0x6C5CE7), Color(hex: 0xA29BFE)]
            case .sky: colors = [Color(hex: 0x54A0FF), Color(hex: 0x00D2A8)]
            case .mint: colors = [Color(hex: 0x00D2A8), Color(hex: 0x55EFC4)]
            case .sunshine: colors = [Color(hex: 0xFDCB6E), Color(hex: 0xFFA801)]
            case .pink: colors = [Color(hex: 0xFD79A8), Color(hex: 0xFF6B6B)]
            }
            return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        var title: String {
            switch self {
            case .violet: return "紫"
            case .sky: return "天空"
            case .mint: return "薄荷"
            case .sunshine: return "暖阳"
            case .pink: return "蜜桃"
            }
        }
    }

    static let `default` = AvatarConfig()
}
