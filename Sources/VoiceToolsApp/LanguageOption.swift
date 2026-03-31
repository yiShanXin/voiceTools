import Foundation

enum LanguageOption: String, CaseIterable {
    case zhCN = "zh-CN"
    case enUS = "en-US"
    case zhTW = "zh-TW"
    case jaJP = "ja-JP"
    case koKR = "ko-KR"

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var menuTitle: String {
        switch self {
        case .zhCN: return "简体中文"
        case .enUS: return "English"
        case .zhTW: return "繁體中文"
        case .jaJP: return "日本語"
        case .koKR: return "한국어"
        }
    }
}
