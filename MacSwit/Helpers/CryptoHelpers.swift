import Foundation
import CryptoKit

/// Tuya API imzalama için kullanılan kriptografik yardımcı fonksiyonlar.
extension Data {
    /// Data'yı küçük harfli hex string'e dönüştürür.
    nonisolated var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

/// Verilen Data'nın SHA-256 hash'ini hex string olarak döndürür.
nonisolated func sha256Hex(of data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return Data(digest).hexString
}

/// HMAC-SHA256 imzası oluşturur ve büyük harfli hex string olarak döndürür.
nonisolated func hmacSHA256Hex(message: String, secret: String) -> String {
    let key = SymmetricKey(data: Data(secret.utf8))
    let signature = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
    return Data(signature).hexString.uppercased()
}
