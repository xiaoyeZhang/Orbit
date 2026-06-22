import Foundation

/// 头像配置 — 纯数据，无 SwiftUI 依赖。
/// Color / LinearGradient 计算属性在 OrbitUI 通过 extension 添加。
public struct AvatarConfig: Codable, Equatable, Hashable, Sendable {
    public var skinTone: SkinTone
    public var hair: HairStyle
    public var hairColor: HairColor
    public var accessory: Accessory
    public var background: BackgroundStyle

    public init(skinTone: SkinTone = .medium, hair: HairStyle = .short,
                hairColor: HairColor = .brown, accessory: Accessory = .none,
                background: BackgroundStyle = .violet) {
        self.skinTone = skinTone; self.hair = hair; self.hairColor = hairColor
        self.accessory = accessory; self.background = background
    }

    public static let `default` = AvatarConfig()

    public enum SkinTone: String, Codable, CaseIterable, Identifiable, Sendable {
        case light, medium, tan, deep
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .light: return "白皙"; case .medium: return "自然"
            case .tan: return "小麦"; case .deep: return "深邃"
            }
        }
    }

    public enum HairStyle: String, Codable, CaseIterable, Identifiable, Sendable {
        case short, long, bun, bald
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .short: return "短发"; case .long: return "长发"
            case .bun: return "丸子头"; case .bald: return "光头"
            }
        }
    }

    public enum HairColor: String, Codable, CaseIterable, Identifiable, Sendable {
        case black, brown, blonde, pink
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .black: return "黑色"; case .brown: return "棕色"
            case .blonde: return "金色"; case .pink: return "粉色"
            }
        }
    }

    public enum Accessory: String, Codable, CaseIterable, Identifiable, Sendable {
        case none, glasses, cap
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .none: return "无"; case .glasses: return "眼镜"; case .cap: return "帽子"
            }
        }
    }

    public enum BackgroundStyle: String, Codable, CaseIterable, Identifiable, Sendable {
        case violet, sky, mint, sunshine, pink
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .violet: return "紫"; case .sky: return "天空"
            case .mint: return "薄荷"; case .sunshine: return "暖阳"; case .pink: return "蜜桃"
            }
        }
    }
}
