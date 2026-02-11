import Foundation

/// Errors that can occur during TP-Link Cloud API communication.
nonisolated enum TPLinkClientError: LocalizedError {
    case missingConfiguration
    case invalidURL
    case invalidResponse(String)
    case httpError(Int)
    case apiError(code: Int, message: String)
    case emptyCredentials
    case loginFailed(String)
    case deviceOffline

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "TP-Link client is not configured. Please fill in email, password, and region."
        case .invalidURL:
            return "Unable to construct TP-Link API URL."
        case .invalidResponse(let details):
            return "Invalid response: \(details)"
        case .httpError(let statusCode):
            return "HTTP error \(statusCode)"
        case .apiError(let code, let message):
            return "TP-Link API error (\(code)): \(message)"
        case .emptyCredentials:
            return "TP-Link email / password is missing."
        case .loginFailed(let details):
            return "Login failed: \(details)"
        case .deviceOffline:
            return "Device is offline. Check that the plug is powered and connected to WiFi."
        }
    }
}

/// Actor that manages communication with the TP-Link Cloud REST API.
///
/// Handles authentication via email/password, token caching, device status
/// queries, and on/off commands through the passthrough interface.
actor TPLinkClient {
    struct Configuration: Equatable, Sendable {
        var endpoint: TPLinkEndpoint
        var email: String
        var password: String
    }

    private struct CachedToken: Sendable {
        let token: String
        let createdAt: Date

        /// TP-Link tokens are long-lived, but we refresh after 12 hours
        /// to avoid stale sessions.
        var isValid: Bool {
            createdAt.timeIntervalSinceNow > -43200
        }
    }

    private let session: URLSession
    private var configuration: Configuration?
    private var cachedToken: CachedToken?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func updateConfiguration(_ configuration: Configuration?) {
        self.configuration = configuration
        cachedToken = nil
    }

    func sendDeviceCommand(deviceId: String, value: Bool) async throws {
        let token = try await ensureToken()
        let config = try ensureConfiguration()

        let relayState = value ? 1 : 0
        let requestData = "{\"system\":{\"set_relay_state\":{\"state\":\(relayState)}}}"

        let body = TPLinkRequest(
            method: "passthrough",
            params: .passthrough(TPLinkPassthroughParams(
                deviceId: deviceId,
                requestData: requestData,
                token: token
            ))
        )

        let response = try await performRequest(config: config, body: body, token: token)

        if response.errorCode != 0 {
            throw TPLinkClientError.apiError(
                code: response.errorCode,
                message: response.msg ?? "Command failed"
            )
        }
    }

    func checkDeviceOnline(deviceId: String) async throws -> Bool {
        let token = try await ensureToken()
        let config = try ensureConfiguration()

        let requestData = "{\"system\":{\"get_sysinfo\":{}}}"

        let body = TPLinkRequest(
            method: "passthrough",
            params: .passthrough(TPLinkPassthroughParams(
                deviceId: deviceId,
                requestData: requestData,
                token: token
            ))
        )

        let response = try await performRequest(config: config, body: body, token: token)
        return response.errorCode == 0
    }

    func testAuthentication() async throws {
        _ = try await ensureToken(forceRefresh: true)
    }
}

// MARK: - Private

private extension TPLinkClient {
    func ensureConfiguration() throws -> Configuration {
        guard let configuration else { throw TPLinkClientError.missingConfiguration }
        guard !configuration.email.isEmpty, !configuration.password.isEmpty else {
            throw TPLinkClientError.emptyCredentials
        }
        return configuration
    }

    func ensureToken(forceRefresh: Bool = false) async throws -> String {
        if !forceRefresh, let cachedToken, cachedToken.isValid {
            return cachedToken.token
        }
        let newToken = try await login()
        cachedToken = newToken
        return newToken.token
    }

    func login() async throws -> CachedToken {
        let config = try ensureConfiguration()
        let terminalUUID = UUID().uuidString

        let body = TPLinkRequest(
            method: "login",
            params: .login(TPLinkLoginParams(
                appType: "Kasa_Android",
                cloudUserName: config.email,
                cloudPassword: config.password,
                terminalUUID: terminalUUID
            ))
        )

        let response = try await performRequest(config: config, body: body, token: nil)

        guard response.errorCode == 0 else {
            throw TPLinkClientError.loginFailed(response.msg ?? "Error code: \(response.errorCode)")
        }

        guard let token = response.result?.token, !token.isEmpty else {
            throw TPLinkClientError.loginFailed("No token in response")
        }

        return CachedToken(token: token, createdAt: Date())
    }

    func performRequest(
        config: Configuration,
        body: TPLinkRequest,
        token: String?
    ) async throws -> TPLinkResponse {
        var url = config.endpoint.baseURL
        if let token {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw TPLinkClientError.invalidURL
            }
            components.queryItems = [URLQueryItem(name: "token", value: token)]
            guard let tokenURL = components.url else {
                throw TPLinkClientError.invalidURL
            }
            url = tokenURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TPLinkClientError.invalidResponse("No HTTP response")
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw TPLinkClientError.httpError(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(TPLinkResponse.self, from: data)
        } catch {
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode"
            throw TPLinkClientError.invalidResponse(String(responseString.prefix(200)))
        }
    }
}

// MARK: - DTOs

/// Unified request body for TP-Link Cloud API.
private struct TPLinkRequest: Encodable, Sendable {
    let method: String
    let params: TPLinkParams

    enum TPLinkParams: Encodable, Sendable {
        case login(TPLinkLoginParams)
        case passthrough(TPLinkPassthroughParams)

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .login(let params):
                try container.encode(params)
            case .passthrough(let params):
                try container.encode(params)
            }
        }
    }
}

private struct TPLinkLoginParams: Encodable, Sendable {
    let appType: String
    let cloudUserName: String
    let cloudPassword: String
    let terminalUUID: String
}

private struct TPLinkPassthroughParams: Encodable, Sendable {
    let deviceId: String
    let requestData: String
    let token: String?

    enum CodingKeys: String, CodingKey {
        case deviceId
        case requestData
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(requestData, forKey: .requestData)
    }
}

/// Response from the TP-Link Cloud API.
private struct TPLinkResponse: Decodable, Sendable {
    let errorCode: Int
    let msg: String?
    let result: TPLinkResult?

    enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case msg
        case result
    }
}

private struct TPLinkResult: Decodable, Sendable {
    let token: String?
    let responseData: String?
}
