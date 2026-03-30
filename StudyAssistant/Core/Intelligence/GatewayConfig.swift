import Foundation

/// Persists cloud gateway connection details to UserDefaults.
/// Shared via the environment so SettingsView and AIService both read the same instance.
@MainActor
@Observable
final class GatewayConfig {

    // MARK: - Persisted properties

    var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: Keys.baseURL) }
    }
    var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: Keys.apiKey) }
    }
    var model: String {
        didSet { UserDefaults.standard.set(model, forKey: Keys.model) }
    }

    // MARK: - Derived

    var isConfigured: Bool { !baseURL.isEmpty && !apiKey.isEmpty }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard
        baseURL = defaults.string(forKey: Keys.baseURL) ?? ""
        apiKey  = defaults.string(forKey: Keys.apiKey)  ?? ""
        model   = defaults.string(forKey: Keys.model)   ?? "gpt-4o-mini"
    }

    // MARK: - Keys

    private enum Keys {
        static let baseURL = "gateway.baseURL"
        static let apiKey  = "gateway.apiKey"
        static let model   = "gateway.model"
    }

    // MARK: - Available models

    static let availableModels: [(id: String, label: String)] = [
        ("gpt-4o-mini",  "GPT-4o mini  (fast, cheap)"),
        ("gpt-4o",       "GPT-4o  (high quality)"),
        ("gemini-pro",   "Gemini 1.5 Pro"),
        ("claude-haiku", "Claude Haiku"),
    ]
}
