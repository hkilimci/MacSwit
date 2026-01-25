import Foundation

enum SettingsMigration {
    private static let migrationVersionKey = "MacSwit.migrationVersion"
    private static let currentVersion = 1

    /// Run all pending migrations
    static func runMigrations() {
        let defaults = UserDefaults.standard
        let lastVersion = defaults.integer(forKey: migrationVersionKey)

        if lastVersion < 1 {
            migrateToProviderKeys()
        }

        defaults.set(currentVersion, forKey: migrationVersionKey)
    }

    /// Migrate old Tuya keys to new provider-prefixed keys
    private static func migrateToProviderKeys() {
        let defaults = UserDefaults.standard
        let keychain = KeychainStore.shared

        // Old keys -> new provider-prefixed keys
        let keyMappings: [(old: String, new: String)] = [
            ("MacSwit.endpointSelection", TuyaSettingsKey.endpointSelection),
            ("MacSwit.customEndpoint", TuyaSettingsKey.customEndpoint),
            ("MacSwit.accessId", TuyaSettingsKey.accessId),
            ("MacSwit.deviceId", TuyaSettingsKey.deviceId),
            ("MacSwit.dpCode", TuyaSettingsKey.dpCode),
        ]

        for (oldKey, newKey) in keyMappings {
            if let value = defaults.string(forKey: oldKey), !value.isEmpty {
                // Only migrate if new key doesn't already have a value
                if defaults.string(forKey: newKey) == nil {
                    defaults.set(value, forKey: newKey)
                }
            }
        }

        // Migrate keychain secret
        let oldAccount = "MacSwit.accessSecret"
        let newAccount = TuyaKeychainAccount.accessSecret

        if let secret = try? keychain.readSecret(account: oldAccount), !secret.isEmpty {
            // Only migrate if new account doesn't already have a value
            if (try? keychain.readSecret(account: newAccount)) == nil {
                try? keychain.saveSecret(secret, account: newAccount)
            }
        }

        // Set default provider to Tuya for existing users
        if defaults.string(forKey: ProviderSettingsKeys.selectedProvider) == nil {
            defaults.set(ProviderType.tuya.rawValue, forKey: ProviderSettingsKeys.selectedProvider)
        }
    }
}
