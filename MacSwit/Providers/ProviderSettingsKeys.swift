import Foundation

/// Generates provider-specific storage keys
enum ProviderSettingsKeys {
    /// UserDefaults key for the selected provider
    static let selectedProvider = "MacSwit.selectedProvider"

    /// Generate a provider-prefixed UserDefaults key
    static func userDefaultsKey(provider: ProviderType, key: String) -> String {
        return "MacSwit.\(provider.rawValue).\(key)"
    }

    /// Generate a provider-prefixed Keychain account
    static func keychainAccount(provider: ProviderType, key: String) -> String {
        return "MacSwit.\(provider.rawValue).\(key)"
    }
}
