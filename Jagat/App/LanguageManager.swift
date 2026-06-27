import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case zh = "zh-Hans"
    case en = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zh: return "中文（简体）"
        case .en: return "English"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }

    var flag: String {
        switch self {
        case .zh: return "🇨🇳"
        case .en: return "🇬🇧"
        }
    }
}

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var current: AppLanguage {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: "appLanguage")
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage")
        // Default: follow system language
        if let saved, let lang = AppLanguage(rawValue: saved) {
            current = lang
        } else {
            let systemLang = Locale.current.languageCode ?? "zh"
            current = systemLang.hasPrefix("en") ? .en : .zh
        }
    }
}
