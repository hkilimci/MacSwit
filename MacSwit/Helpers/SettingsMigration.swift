import Foundation

enum SettingsMigration {
    private static let migrationVersionKey = "MacSwit.migrationVersion"
    private static let currentVersion = 2

    /// Run all pending migrations
    static func runMigrations() {
        let defaults = UserDefaults.standard
        let lastVersion = defaults.integer(forKey: migrationVersionKey)

        if lastVersion < 1 {
            migrateToProviderKeys()
        }

        if lastVersion < 2 {
            migrateToPlugConfigs()
        }

        defaults.set(currentVersion, forKey: migrationVersionKey)
    }

    /// v1: Migrate old Tuya keys to provider-prefixed keys
    private static func migrateToProviderKeys() {
        let defaults = UserDefaults.standard
        let keychain = KeychainStore.shared

        let keyMappings: [(old: String, new: String)] = [
            ("MacSwit.endpointSelection", "MacSwit.tuya.endpointSelection"),
            ("MacSwit.customEndpoint", "MacSwit.tuya.customEndpoint"),
            ("MacSwit.accessId", "MacSwit.tuya.accessId"),
            ("MacSwit.deviceId", "MacSwit.tuya.deviceId"),
            ("MacSwit.dpCode", "MacSwit.tuya.dpCode"),
        ]

        for (oldKey, newKey) in keyMappings {
            if let value = defaults.string(forKey: oldKey), !value.isEmpty {
                if defaults.string(forKey: newKey) == nil {
                    defaults.set(value, forKey: newKey)
                }
            }
        }

        let oldAccount = "MacSwit.accessSecret"
        let newAccount = "MacSwit.tuya.accessSecret"

        if let secret = try? keychain.readSecret(account: oldAccount), !secret.isEmpty {
            if (try? keychain.readSecret(account: newAccount)) == nil {
                try? keychain.saveSecret(secret, account: newAccount)
            }
        }

        if defaults.string(forKey: "MacSwit.selectedProvider") == nil {
            defaults.set(ProviderType.tuya.rawValue, forKey: "MacSwit.selectedProvider")
        }
    }

    /// v2: Migrate provider-prefixed keys to PlugConfig array
    private static func migrateToPlugConfigs() {
        let defaults = UserDefaults.standard
        let keychain = KeychainStore.shared

        // Already migrated?
        if defaults.data(forKey: "MacSwit.plugConfigs") != nil { return }

        // Read existing Tuya settings (from v1 keys)
        let endpointSelection = defaults.string(forKey: "MacSwit.tuya.endpointSelection") ?? TuyaEndpoint.centralEurope.id
        let customEndpoint = defaults.string(forKey: "MacSwit.tuya.customEndpoint") ?? ""
        let accessId = defaults.string(forKey: "MacSwit.tuya.accessId") ?? ""
        let deviceId = defaults.string(forKey: "MacSwit.tuya.deviceId") ?? ""
        let dpCode = defaults.string(forKey: "MacSwit.tuya.dpCode") ?? "switch_1"
        let accessSecret = (try? keychain.readSecret(account: "MacSwit.tuya.accessSecret")) ?? ""

        // Only create a plug config if there's meaningful configuration
        let hasConfig = !accessId.isEmpty || !deviceId.isEmpty || !accessSecret.isEmpty
        guard hasConfig else { return }

        let config = PlugConfig(
            name: "My Plug",
            providerType: .tuya,
            tuyaEndpointSelection: endpointSelection,
            tuyaCustomEndpoint: customEndpoint,
            tuyaAccessId: accessId,
            tuyaDeviceId: deviceId,
            tuyaDpCode: dpCode
        )

        // Save secret under new keychain key
        if !accessSecret.isEmpty {
            try? keychain.saveSecret(accessSecret, account: config.keychainAccount)
        }

        // Encode and persist
        if let data = try? JSONEncoder().encode([config]) {
            defaults.set(data, forKey: "MacSwit.plugConfigs")
        }
        defaults.set(config.id.uuidString, forKey: "MacSwit.activePlugId")
    }
}
