import Foundation

enum TuyaClientError: LocalizedError {
    case missingConfiguration
    case invalidURL
    case invalidResponse(String)
    case httpError(Int)
    case apiError(code: String, message: String)
    case emptyCredentials
    case deviceOffline

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Tuya client is not configured. Please fill in Access ID, Secret, and endpoint."
        case .invalidURL:
            return "Unable to construct Tuya API URL."
        case .invalidResponse(let details):
            return "Invalid response: \(details)"
        case .httpError(let statusCode):
            return "HTTP error \(statusCode)"
        case .apiError(let code, let message):
            return "Tuya API error (\(code)): \(message)"
        case .emptyCredentials:
            return "Tuya Access ID / Secret is missing."
        case .deviceOffline:
            return "Device is offline. Check that the plug is powered and connected to WiFi."
        }
    }
}

actor TuyaClient {
    struct Configuration: Equatable {
        var endpoint: TuyaEndpoint
        var accessId: String
        var accessSecret: String
    }

    struct DeviceConfiguration: Equatable {
        var deviceId: String
        var dpCode: String
    }

    private struct CachedToken {
        let token: String
        let expiresAt: Date

        var isValid: Bool {
            expiresAt.timeIntervalSinceNow > 60
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

    func clearToken() {
        cachedToken = nil
    }

    func sendDeviceCommand(device: DeviceConfiguration, value: Bool) async throws {
        // Check if device is online first
        let isOnline = try await checkDeviceOnline(deviceId: device.deviceId)
        guard isOnline else {
            throw TuyaClientError.deviceOffline
        }

        let body = TuyaCommandBody(commands: [.init(code: device.dpCode, value: value)])
        let data = try JSONEncoder().encode(body)
        let path = "/v1.0/iot-03/devices/\(device.deviceId)/commands"
        let response: TuyaAPIResponse<Bool> = try await performRequest(path: path, method: "POST", body: data)
        guard response.success else {
            throw TuyaClientError.apiError(code: response.code ?? "unknown", message: response.msg ?? "Command failed")
        }
        // Verify the command was actually executed (result should be true)
        guard response.result == true else {
            throw TuyaClientError.apiError(code: "command_not_executed", message: "Device did not confirm command execution")
        }
    }

    func checkDeviceOnline(deviceId: String) async throws -> Bool {
        let path = "/v1.0/iot-03/devices/\(deviceId)"
        let response: TuyaAPIResponse<DeviceInfo> = try await performRequest(path: path, method: "GET", body: nil)
        guard response.success, let result = response.result else {
            throw TuyaClientError.apiError(code: response.code ?? "unknown", message: response.msg ?? "Failed to get device status")
        }
        return result.online
    }

    func testAuthentication() async throws {
        _ = try await ensureToken(forceRefresh: true)
    }
}

// MARK: - Private

private extension TuyaClient {
    func ensureConfiguration() throws -> Configuration {
        guard let configuration else { throw TuyaClientError.missingConfiguration }
        guard !configuration.accessId.isEmpty, !configuration.accessSecret.isEmpty else {
            throw TuyaClientError.emptyCredentials
        }
        return configuration
    }

    func ensureToken(forceRefresh: Bool = false) async throws -> String {
        if !forceRefresh, let cachedToken, cachedToken.isValid {
            return cachedToken.token
        }
        let newToken = try await requestToken()
        cachedToken = newToken
        return newToken.token
    }

    private func requestToken() async throws -> CachedToken {
        let response: TuyaAPIResponse<TokenPayload> = try await performRequest(path: "/v1.0/token?grant_type=1", method: "GET", body: nil, includeToken: false)
        guard response.success, let result = response.result else {
            throw TuyaClientError.apiError(code: response.code ?? "unknown", message: response.msg ?? "Failed to fetch token")
        }
        let expires = Date().addingTimeInterval(TimeInterval(result.expireTime))
        return CachedToken(token: result.accessToken, expiresAt: expires)
    }

    func performRequest<Result: Decodable>(
        path: String,
        method: String,
        body: Data?,
        includeToken: Bool = true
    ) async throws -> TuyaAPIResponse<Result> {
        let configuration = try ensureConfiguration()
        let url = try makeURL(for: configuration.endpoint, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } else if method == "POST" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let token = includeToken ? try await ensureToken() : nil
        applySignature(config: configuration, request: &request, token: token)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TuyaClientError.invalidResponse("No HTTP response")
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            // Try to parse error response for more details
            if let errorResponse = try? JSONDecoder().decode(TuyaAPIResponse<EmptyResult>.self, from: data) {
                throw TuyaClientError.apiError(code: errorResponse.code ?? "\(httpResponse.statusCode)", message: errorResponse.msg ?? "HTTP error")
            }
            throw TuyaClientError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let decoded = try decoder.decode(TuyaAPIResponse<Result>.self, from: data)
            return decoded
        } catch {
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode"
            throw TuyaClientError.invalidResponse(String(responseString.prefix(200)))
        }
    }

    func makeURL(for endpoint: TuyaEndpoint, path: String) throws -> URL {
        guard var components = URLComponents(url: endpoint.baseURL, resolvingAgainstBaseURL: false) else {
            throw TuyaClientError.invalidURL
        }
        if let pathComponents = URLComponents(string: path) {
            components.path = pathComponents.path
            components.query = pathComponents.query
        } else {
            components.path = path
        }
        guard let url = components.url else {
            throw TuyaClientError.invalidURL
        }
        return url
    }

    func applySignature(config: Configuration, request: inout URLRequest, token: String?) {
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        let bodyData = request.httpBody ?? Data()
        let contentHash = sha256Hex(of: bodyData)
        let urlForSign = request.url ?? URL(string: "/")!
        var path = urlForSign.path.isEmpty ? "/" : urlForSign.path
        if let query = urlForSign.query, !query.isEmpty {
            path += "?\(query)"
        }

        let stringToSign = "\(request.httpMethod ?? "GET")\n\(contentHash)\n\n\(path)"
        let signSource = config.accessId + (token ?? "") + timestamp + stringToSign
        let signature = hmacSHA256Hex(message: signSource, secret: config.accessSecret)

        request.setValue(config.accessId, forHTTPHeaderField: "client_id")
        request.setValue(timestamp, forHTTPHeaderField: "t")
        request.setValue("HMAC-SHA256", forHTTPHeaderField: "sign_method")
        request.setValue(signature, forHTTPHeaderField: "sign")
        if let token {
            request.setValue(token, forHTTPHeaderField: "access_token")
        }
    }
}

// MARK: - DTOs

private struct TuyaCommandBody: Encodable {
    struct Command: Encodable {
        let code: String
        let value: Bool
    }

    let commands: [Command]
}

private struct EmptyResult: Decodable {}

private struct DeviceInfo: Decodable {
    let online: Bool
}

struct TuyaAPIResponse<Result: Decodable>: Decodable {
    let success: Bool
    let t: Int
    let result: Result?
    let code: String?
    let msg: String?
}

private struct TokenPayload: Decodable {
    let accessToken: String
    let expireTime: TimeInterval
}
