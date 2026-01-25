import Foundation
import CryptoKit

extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

func sha256Hex(of data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return Data(digest).hexString
}

func hmacSHA256Hex(message: String, secret: String) -> String {
    let key = SymmetricKey(data: Data(secret.utf8))
    let signature = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
    return Data(signature).hexString.uppercased()
}
