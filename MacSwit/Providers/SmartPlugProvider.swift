import Foundation

/// Identifies available smart plug providers
enum ProviderType: String, CaseIterable, Identifiable, Codable {
    case tuya = "tuya"
    // Future providers:
    // case meross = "meross"
    // case kasa = "kasa"
    // case shelly = "shelly"

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

/// Protocol that all smart plug providers must implement
@MainActor
protocol SmartPlugProvider: AnyObject {
    /// Unique identifier for this provider type
    var providerType: ProviderType { get }

    /// Human-readable name for display
    var displayName: String { get }

    /// Whether the provider has valid configuration
    var isConfigured: Bool { get }

    /// Send on/off command to the configured device
    func sendCommand(value: Bool) async throws

    /// Test the connection/authentication without sending commands
    func testConnection() async throws

    /// Load configuration from storage (UserDefaults + Keychain)
    func loadConfiguration()

    /// Clear cached tokens/state (e.g., when credentials change)
    func clearCache()
}
