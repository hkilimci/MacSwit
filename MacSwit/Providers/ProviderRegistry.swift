import Foundation

/// Factory and registry for smart plug providers
@MainActor
final class ProviderRegistry {
    static let shared = ProviderRegistry()

    private var providers: [ProviderType: any SmartPlugProvider] = [:]

    private init() {
        // Register all available providers
        registerProvider(TuyaProvider())
        // Future: registerProvider(MerossProvider())
    }

    func registerProvider(_ provider: any SmartPlugProvider) {
        providers[provider.providerType] = provider
    }

    func provider(for type: ProviderType) -> (any SmartPlugProvider)? {
        return providers[type]
    }

    var availableProviders: [ProviderType] {
        return ProviderType.allCases.filter { providers[$0] != nil }
    }
}
