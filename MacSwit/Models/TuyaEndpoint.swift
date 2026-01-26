import Foundation

struct TuyaEndpoint: Identifiable, Equatable {
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

    static let china = TuyaEndpoint(
        id: "cn",
        name: "China",
        host: "openapi.tuyacn.com",
        isCustom: false
    )

    static let westernAmerica = TuyaEndpoint(
        id: "us",
        name: "Western America",
        host: "openapi.tuyaus.com",
        isCustom: false
    )

    static let easternAmerica = TuyaEndpoint(
        id: "usEast",
        name: "Eastern America",
        host: "openapi-ueaz.tuyaus.com",
        isCustom: false
    )

    static let centralEurope = TuyaEndpoint(
        id: "eu",
        name: "Central Europe",
        host: "openapi.tuyaeu.com",
        isCustom: false
    )

    static let westernEurope = TuyaEndpoint(
        id: "euWest",
        name: "Western Europe",
        host: "openapi-weaz.tuyaeu.com",
        isCustom: false
    )

    static let india = TuyaEndpoint(
        id: "in",
        name: "India",
        host: "openapi.tuyain.com",
        isCustom: false
    )

    static let singapore = TuyaEndpoint(
        id: "sg",
        name: "Singapore",
        host: "openapi-sg.iotbing.com",
        isCustom: false
    )

    static let custom = TuyaEndpoint(id: "custom", name: "Custom", host: "", isCustom: true)

    static var presets: [TuyaEndpoint] {
        [
            TuyaEndpoint.china,
            TuyaEndpoint.westernAmerica,
            TuyaEndpoint.easternAmerica,
            TuyaEndpoint.centralEurope,
            TuyaEndpoint.westernEurope,
            TuyaEndpoint.india,
            TuyaEndpoint.singapore,
            TuyaEndpoint.custom
        ]
    }

    static func endpoint(selection: String, customHost: String) -> TuyaEndpoint {
        if selection == TuyaEndpoint.custom.id {
            let host = customHost.trimmingCharacters(in: .whitespacesAndNewlines)
            return TuyaEndpoint(
                id: "custom",
                name: "Custom",
                host: host.isEmpty ? TuyaEndpoint.centralEurope.host : host,
                isCustom: true
            )
        }
        return TuyaEndpoint.presets.first(where: { $0.id == selection }) ?? .centralEurope
    }
}
