import Foundation

/// Tuya-specific settings keys
enum TuyaSettingsKey {
    static let endpointSelection = ProviderSettingsKeys.userDefaultsKey(provider: .tuya, key: "endpointSelection")
    static let customEndpoint = ProviderSettingsKeys.userDefaultsKey(provider: .tuya, key: "customEndpoint")
    static let accessId = ProviderSettingsKeys.userDefaultsKey(provider: .tuya, key: "accessId")
    static let deviceId = ProviderSettingsKeys.userDefaultsKey(provider: .tuya, key: "deviceId")
    static let dpCode = ProviderSettingsKeys.userDefaultsKey(provider: .tuya, key: "dpCode")
}

enum TuyaKeychainAccount {
    static let accessSecret = ProviderSettingsKeys.keychainAccount(provider: .tuya, key: "accessSecret")
}

@MainActor
final class TuyaProvider: SmartPlugProvider {
    let providerType: ProviderType = .tuya
    var displayName: String { providerType.displayName }

    private let client = TuyaClient()
    private let keychain = KeychainStore.shared

    // Configuration loaded from storage
    private var endpointSelection: String = TuyaEndpoint.centralEurope.id
    private var customEndpoint: String = ""
    private var accessId: String = ""
    private var accessSecret: String = ""
    private var deviceId: String = ""
    private var dpCode: String = "switch_1"

    var isConfigured: Bool {
        missingConfigurationFields.isEmpty
    }

    var missingConfigurationFields: [String] {
        var missing: [String] = []
        if accessId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missing.append("Access ID")
        }
        if accessSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missing.append("Access Secret")
        }
        if deviceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missing.append("Device ID")
        }
        return missing
    }

    init() {
        loadConfiguration()
    }

    func loadConfiguration() {
        let defaults = UserDefaults.standard
        endpointSelection = defaults.string(forKey: TuyaSettingsKey.endpointSelection) ?? TuyaEndpoint.centralEurope.id
        customEndpoint = defaults.string(forKey: TuyaSettingsKey.customEndpoint) ?? ""
        accessId = defaults.string(forKey: TuyaSettingsKey.accessId) ?? ""
        deviceId = defaults.string(forKey: TuyaSettingsKey.deviceId) ?? ""
        dpCode = defaults.string(forKey: TuyaSettingsKey.dpCode) ?? "switch_1"
        accessSecret = (try? keychain.readSecret(account: TuyaKeychainAccount.accessSecret)) ?? ""

        applyConfiguration()
    }

    func clearCache() {
        Task {
            await client.clearToken()
        }
    }

    func sendCommand(value: Bool) async throws {
        guard isConfigured else {
            throw ProviderError.notConfigured
        }

        let trimmedDeviceId = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDeviceId.isEmpty else {
            throw ProviderError.missingDeviceId
        }

        let code = dpCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "switch_1" : dpCode
        let device = TuyaClient.DeviceConfiguration(deviceId: trimmedDeviceId, dpCode: code)

        do {
            try await client.sendDeviceCommand(device: device, value: value)
        } catch {
            throw ProviderError.commandFailed(error.localizedDescription)
        }
    }

    func testConnection() async throws {
        guard isConfigured else {
            throw ProviderError.notConfigured
        }

        do {
            try await client.testAuthentication()
        } catch {
            throw ProviderError.connectionFailed(error.localizedDescription)
        }
    }

    // MARK: - Settings UI Support

    func saveAccessSecret(_ value: String) throws {
        if value.isEmpty {
            try keychain.deleteSecret(account: TuyaKeychainAccount.accessSecret)
        } else {
            try keychain.saveSecret(value, account: TuyaKeychainAccount.accessSecret)
        }
        accessSecret = value
        applyConfiguration()
    }

    func getAccessSecret() -> String {
        return accessSecret
    }

    private func applyConfiguration() {
        Task {
            let trimmedSecret = accessSecret.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedAccessId = accessId.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedSecret.isEmpty, !trimmedAccessId.isEmpty else {
                await client.updateConfiguration(nil)
                return
            }

            let endpoint = TuyaEndpoint.endpoint(selection: endpointSelection, customHost: customEndpoint)
            let configuration = TuyaClient.Configuration(
                endpoint: endpoint,
                accessId: trimmedAccessId,
                accessSecret: trimmedSecret
            )
            await client.updateConfiguration(configuration)
        }
    }
}
