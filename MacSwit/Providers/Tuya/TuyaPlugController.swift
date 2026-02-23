import Foundation

/// Tuya-specific implementation of `PlugProviding`.
///
/// Created by `PlugProviderFactory` when `config.providerType == .tuya`.
/// Reads Tuya-specific fields from `PlugConfig` and drives a `TuyaClient`.
@MainActor
final class TuyaPlugController: PlugProviding {
    private let config: PlugConfig
    private let client: TuyaClient
    private let accessId: String
    private let accessSecret: String
    private var configApplied = false

    init(config: PlugConfig, accessId: String, accessSecret: String) {
        self.config = config
        self.accessId = accessId
        self.accessSecret = accessSecret
        self.client = TuyaClient()
    }

    var isConfigured: Bool {
        missingFields.isEmpty
    }

    var missingFields: [String] {
        var missing: [String] = []
        if accessId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missing.append("Access ID")
        }
        if accessSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missing.append("Access Secret")
        }
        if config.tuyaDeviceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missing.append("Device ID")
        }
        return missing
    }

    func sendCommand(value: Bool) async throws {
        guard isConfigured else {
            throw ProviderError.notConfigured
        }

        await ensureClientConfigured()

        let trimmedDeviceId = config.tuyaDeviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDeviceId.isEmpty else {
            throw ProviderError.missingDeviceId
        }

        let dpCode = config.tuyaDpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = dpCode.isEmpty ? "switch_1" : dpCode
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

        await ensureClientConfigured()

        do {
            try await client.testAuthentication()
        } catch {
            throw ProviderError.connectionFailed(error.localizedDescription)
        }
    }

    func warmToken() async throws {
        await ensureClientConfigured()
        try await client.warmToken()
    }

    func sendShutdownCommandFast() async throws {
        guard isConfigured else {
            throw ProviderError.notConfigured
        }

        await ensureClientConfigured()

        let trimmedDeviceId = config.tuyaDeviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDeviceId.isEmpty else {
            throw ProviderError.missingDeviceId
        }

        let dpCode = config.tuyaDpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = dpCode.isEmpty ? "switch_1" : dpCode
        let device = TuyaClient.DeviceConfiguration(deviceId: trimmedDeviceId, dpCode: code)

        do {
            try await client.sendShutdownCommand(device: device)
        } catch {
            throw ProviderError.commandFailed(error.localizedDescription)
        }
    }

    /// Applies the configuration to the TuyaClient actor exactly once,
    /// awaiting completion so the client is ready before any request.
    private func ensureClientConfigured() async {
        guard !configApplied else { return }
        configApplied = true

        let trimmedSecret = accessSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAccessId = accessId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedSecret.isEmpty, !trimmedAccessId.isEmpty else {
            await client.updateConfiguration(nil)
            return
        }

        let endpoint = TuyaEndpoint.endpoint(
            selection: config.tuyaEndpointSelection,
            customHost: config.tuyaCustomEndpoint
        )
        let configuration = TuyaClient.Configuration(
            endpoint: endpoint,
            accessId: trimmedAccessId,
            accessSecret: trimmedSecret
        )
        await client.updateConfiguration(configuration)
    }
}
