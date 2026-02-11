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
    case tplink = "tplink"
    // case meross = "meross"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tuya: return "Tuya"
        case .tplink: return "TP-Link Kasa"
        }
    }

    var iconName: String {
        switch self {
        case .tuya: return "network"
        case .tplink: return "wifi"
        }
    }
}

// =============================================================================
// MARK: - Provider Errors
// =============================================================================

/// Errors that any provider can throw
enum ProviderError: LocalizedError {
    case notConfigured
    case connectionFailed(String)
    case commandFailed(String)
    case missingDeviceId

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Provider is not configured. Please fill in the required settings."
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
    static func make(config: PlugConfig, accessId: String, accessSecret: String) -> any PlugProviding {
        switch config.providerType {
        case .tuya:
            return TuyaPlugController(config: config, accessId: accessId, accessSecret: accessSecret)
        case .tplink:
            return TPLinkPlugController(config: config, email: accessId, password: accessSecret)
        // case .meross:
        //     return MerossPlugController(config: config, accessId: accessId, accessSecret: accessSecret)
        }
    }
}
