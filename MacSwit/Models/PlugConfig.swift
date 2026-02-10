import Foundation

/// Persisted configuration for a single smart plug.
///
/// Each provider brand stores its fields in a dedicated MARK section below.
/// Credentials (`accessId` and `accessSecret`) are NOT stored here -- they
/// live in the Keychain under the keys returned by `keychainAccessIdAccount`
/// and `keychainAccount`.
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

    /// Keychain account name for this plug's Access Secret.
    var keychainAccount: String {
        "MacSwit.plug.\(id).accessSecret"
    }

    /// Keychain account name for this plug's Access ID.
    var keychainAccessIdAccount: String {
        "MacSwit.plug.\(id).accessId"
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        providerType: ProviderType = .tuya,
        // Tuya
        tuyaEndpointSelection: String = TuyaEndpoint.centralEurope.id,
        tuyaCustomEndpoint: String = "",
        tuyaDeviceId: String = "",
        tuyaDpCode: String = "switch_1"
    ) {
        self.id = id
        self.name = name
        self.providerType = providerType
        self.tuyaEndpointSelection = tuyaEndpointSelection
        self.tuyaCustomEndpoint = tuyaCustomEndpoint
        self.tuyaDeviceId = tuyaDeviceId
        self.tuyaDpCode = tuyaDpCode
    }
}
