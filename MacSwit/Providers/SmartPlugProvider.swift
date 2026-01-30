import Foundation

// =============================================================================
// MARK: - Provider Type
// =============================================================================

/// Identifies available smart plug providers.
///
/// **To add a new provider:**
/// 1. Add a case here (e.g. `case meross = "meross"`)
/// 2. Update `displayName` and `iconName`
/// 3. Create `Providers/<Brand>/<Brand>PlugController.swift` implementing `PlugProviding`
/// 4. Create `Providers/<Brand>/<Brand>PlugFieldsView.swift` with the settings form
/// 5. Add the case to `PlugProviderFactory.make(config:accessSecret:)`
/// 6. Add the case to `PlugEditView.providerFieldsView`
/// 7. Add provider-specific fields to `PlugConfig` in a new MARK section
enum ProviderType: String, CaseIterable, Identifiable, Codable {
    case tuya = "tuya"
    // case meross = "meross"
    // case kasa = "kasa"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tuya: return "Tuya"
        }
    }

    var iconName: String {
        switch self {
        case .tuya: return "network"
        }
    }
}

// =============================================================================
// MARK: - Provider Errors
// =============================================================================

/// Errors that any provider can throw
enum ProviderError: LocalizedError {
    case notConfigured
    case invalidCredentials
    case connectionFailed(String)
    case commandFailed(String)
    case missingDeviceId

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Provider is not configured. Please fill in the required settings."
        case .invalidCredentials:
            return "Invalid credentials. Please check your API keys."
        case .connectionFailed(let details):
            return "Connection failed: \(details)"
        case .commandFailed(let details):
            return "Command failed: \(details)"
        case .missingDeviceId:
            return "Device ID is missing. Please configure a device."
        }
    }
}

// =============================================================================
// MARK: - Provider Protocol
// =============================================================================

/// Protocol that every provider-specific controller must implement.
///
/// Each provider brand (Tuya, Meross, Kasa, etc.) has its own class conforming
/// to this protocol. See `TuyaPlugController` for the reference implementation.
@MainActor
protocol PlugProviding {
    /// Whether the provider has all required configuration filled in
    var isConfigured: Bool { get }

    /// Names of missing configuration fields (empty when fully configured)
    var missingFields: [String] { get }

    /// Send an on/off command to the configured device
    func sendCommand(value: Bool) async throws

    /// Test the connection/authentication without sending a command
    func testConnection() async throws
}

// =============================================================================
// MARK: - Provider Factory
// =============================================================================

/// Creates the correct provider controller for a given plug configuration.
///
/// **To add a new provider**, add a case to the switch below.
enum PlugProviderFactory {
    @MainActor
    static func make(config: PlugConfig, accessSecret: String) -> any PlugProviding {
        switch config.providerType {
        case .tuya:
            return TuyaPlugController(config: config, accessSecret: accessSecret)
        // case .meross:
        //     return MerossPlugController(config: config, accessSecret: accessSecret)
        }
    }
}
