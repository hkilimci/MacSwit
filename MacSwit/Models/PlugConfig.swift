import Foundation

/// Persisted configuration for a single smart plug.
///
/// Each provider brand stores its fields in a dedicated MARK section below.
/// The `accessSecret` is NOT stored here -- it lives in the Keychain under
/// the key returned by `keychainAccount`.
///
/// **To add a new provider's fields:**
/// 1. Add a new MARK section with the provider-specific properties
/// 2. Give them sensible defaults so existing configs decode safely
/// 3. Update the `init` to include the new parameters
struct PlugConfig: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var providerType: ProviderType

    // =========================================================================
    // MARK: - Tuya-specific fields
    // =========================================================================

    var tuyaEndpointSelection: String
    var tuyaCustomEndpoint: String
    var tuyaAccessId: String
    var tuyaDeviceId: String
    var tuyaDpCode: String

    // =========================================================================
    // MARK: - (Next provider) Add fields here
    // =========================================================================
    // var merossEmail: String
    // var merossDeviceId: String

    // =========================================================================
    // MARK: - Keychain
    // =========================================================================

    /// Keychain account name for this plug's secret (e.g. Tuya Access Secret).
    /// Each plug gets its own keychain entry keyed by its UUID.
    var keychainAccount: String {
        "MacSwit.plug.\(id).accessSecret"
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        providerType: ProviderType = .tuya,
        // Tuya
        tuyaEndpointSelection: String = TuyaEndpoint.centralEurope.id,
        tuyaCustomEndpoint: String = "",
        tuyaAccessId: String = "",
        tuyaDeviceId: String = "",
        tuyaDpCode: String = "switch_1"
    ) {
        self.id = id
        self.name = name
        self.providerType = providerType
        self.tuyaEndpointSelection = tuyaEndpointSelection
        self.tuyaCustomEndpoint = tuyaCustomEndpoint
        self.tuyaAccessId = tuyaAccessId
        self.tuyaDeviceId = tuyaDeviceId
        self.tuyaDpCode = tuyaDpCode
    }
}
