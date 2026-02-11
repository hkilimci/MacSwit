import Foundation

/// TP-Link Cloud API regional endpoint definition.
///
/// Each region has a different cloud server host. The user can pick a
/// preset region or enter a custom endpoint URL.
nonisolated struct TPLinkEndpoint: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let host: String
    let isCustom: Bool

    var baseURL: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        return components.url ?? URL(string: "https://\(host)")!
    }

    static let global = TPLinkEndpoint(
        id: "global",
        name: "Global (US)",
        host: "wap.tplinkcloud.com",
        isCustom: false
    )

    static let europe = TPLinkEndpoint(
        id: "eu",
        name: "Europe",
        host: "eu-wap.tplinkcloud.com",
        isCustom: false
    )

    static let asiaPacific = TPLinkEndpoint(
        id: "apac",
        name: "Asia Pacific",
        host: "apac-wap.tplinkcloud.com",
        isCustom: false
    )

    static let custom = TPLinkEndpoint(id: "custom", name: "Custom", host: "", isCustom: true)

    static var presets: [TPLinkEndpoint] {
        [
            TPLinkEndpoint.global,
            TPLinkEndpoint.europe,
            TPLinkEndpoint.asiaPacific,
            TPLinkEndpoint.custom
        ]
    }

    static func endpoint(selection: String, customHost: String) -> TPLinkEndpoint {
        if selection == TPLinkEndpoint.custom.id {
            let host = customHost.trimmingCharacters(in: .whitespacesAndNewlines)
            return TPLinkEndpoint(
                id: "custom",
                name: "Custom",
                host: host.isEmpty ? TPLinkEndpoint.global.host : host,
                isCustom: true
            )
        }
        return TPLinkEndpoint.presets.first(where: { $0.id == selection }) ?? .global
    }
}
