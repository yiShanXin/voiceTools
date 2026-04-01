import Foundation

final class AppConfig {
    static let shared = AppConfig()

    private enum Key {
        static let language = "selectedLanguage"
        static let triggerKey = "triggerKeyOption"
        static let llmEnabled = "llmEnabled"
        static let apiBaseURL = "llmApiBaseURL"
        static let apiKey = "llmApiKey"
        static let model = "llmModel"
    }

    private let defaults = UserDefaults.standard

    private init() {
        if defaults.string(forKey: Key.language) == nil {
            defaults.set(LanguageOption.zhCN.rawValue, forKey: Key.language)
        }
        if defaults.string(forKey: Key.triggerKey) == nil {
            defaults.set(TriggerKeyOption.fnOrRightCommand.rawValue, forKey: Key.triggerKey)
        }
        if defaults.string(forKey: Key.apiBaseURL) == nil {
            defaults.set("https://api.openai.com/v1", forKey: Key.apiBaseURL)
        }
        if defaults.string(forKey: Key.model) == nil {
            defaults.set("gpt-4o-mini", forKey: Key.model)
        }
    }

    var language: LanguageOption {
        get {
            let value = defaults.string(forKey: Key.language) ?? LanguageOption.zhCN.rawValue
            return LanguageOption(rawValue: value) ?? .zhCN
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.language)
        }
    }

    var llmEnabled: Bool {
        get { defaults.bool(forKey: Key.llmEnabled) }
        set { defaults.set(newValue, forKey: Key.llmEnabled) }
    }

    var triggerKey: TriggerKeyOption {
        get {
            let value = defaults.string(forKey: Key.triggerKey) ?? TriggerKeyOption.fnOrRightCommand.rawValue
            return TriggerKeyOption(rawValue: value) ?? .fnOrRightCommand
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.triggerKey)
        }
    }

    var apiBaseURL: String {
        get { defaults.string(forKey: Key.apiBaseURL) ?? "" }
        set { defaults.set(newValue, forKey: Key.apiBaseURL) }
    }

    var apiKey: String {
        get { defaults.string(forKey: Key.apiKey) ?? "" }
        set { defaults.set(newValue, forKey: Key.apiKey) }
    }

    var model: String {
        get { defaults.string(forKey: Key.model) ?? "" }
        set { defaults.set(newValue, forKey: Key.model) }
    }
}
