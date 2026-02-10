import Foundation
import CryptoKit

/// Cryptographic helper functions used for Tuya API request signing.
extension Data {
    /// Converts data to a lowercase hex string.
    nonisolated var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

/// Returns the SHA-256 hash of the given data as a hex string.
nonisolated func sha256Hex(of data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return Data(digest).hexString
}

/// Generates an HMAC-SHA256 signature and returns it as an uppercase hex string.
nonisolated func hmacSHA256Hex(message: String, secret: String) -> String {
    let key = SymmetricKey(data: Data(secret.utf8))
    let signature = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
    return Data(signature).hexString.uppercased()
}
