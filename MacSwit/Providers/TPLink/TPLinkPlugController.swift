import Foundation

/// TP-Link (Kasa) specific implementation of `PlugProviding`.
///
/// Created by `PlugProviderFactory` when `config.providerType == .tplink`.
/// Reads TP-Link-specific fields from `PlugConfig` and drives a `TPLinkClient`.
@MainActor
final class TPLinkPlugController: PlugProviding {
    private let config: PlugConfig
    private let client: TPLinkClient
    private let email: String
    private let password: String
    private var configApplied = false

    init(config: PlugConfig, email: String, password: String) {
        self.config = config
        self.email = email
        self.password = password
        self.client = TPLinkClient()
    }

    var isConfigured: Bool {
        missingFields.isEmpty
    }

    var missingFields: [String] {
        var missing: [String] = []
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missing.append("Email")
        }
        if password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missing.append("Password")
        }
        if config.tplinkDeviceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missing.append("Device ID")
        }
        return missing
    }

    func sendCommand(value: Bool) async throws {
        guard isConfigured else {
            throw ProviderError.notConfigured
        }

        await ensureClientConfigured()

        let trimmedDeviceId = config.tplinkDeviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDeviceId.isEmpty else {
            throw ProviderError.missingDeviceId
        }

        do {
            let isOnline = try await client.checkDeviceOnline(deviceId: trimmedDeviceId)
            guard isOnline else {
                throw ProviderError.commandFailed("Device is offline")
            }
            try await client.sendDeviceCommand(deviceId: trimmedDeviceId, value: value)
        } catch let error as ProviderError {
            throw error
        } catch {
            throw ProviderError.commandFailed(error.localizedDescription)
        }
    }

    func testConnection() async throws {
        guard isConfigured else {
            throw ProviderError.notConfigured
        }

        await ensureClientConfigured()

        do {
            try await client.testAuthentication()
        } catch {
            throw ProviderError.connectionFailed(error.localizedDescription)
        }
    }

    /// Applies the configuration to the TPLinkClient actor exactly once.
    private func ensureClientConfigured() async {
        guard !configApplied else { return }
        configApplied = true

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            await client.updateConfiguration(nil)
            return
        }

        let endpoint = TPLinkEndpoint.endpoint(
            selection: config.tplinkEndpointSelection,
            customHost: config.tplinkCustomEndpoint
        )
        let configuration = TPLinkClient.Configuration(
            endpoint: endpoint,
            email: trimmedEmail,
            password: trimmedPassword
        )
        await client.updateConfiguration(configuration)
    }
}
