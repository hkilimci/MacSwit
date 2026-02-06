import Foundation

/// `UserDefaults` / `@AppStorage` için kullanılan anahtar sabitleri.
enum SettingsKey {
    static let onThreshold = "MacSwit.onThreshold"
    static let offThreshold = "MacSwit.offThreshold"
    static let intervalSec = "MacSwit.intervalSec"
    static let startAtLogin = "MacSwit.startAtLogin"
    static let appEnabled = "MacSwit.appEnabled"
    static let switchOffOnShutdown = "MacSwit.switchOffOnShutdown"
}

/// Uygulama genelinde kullanılan varsayılan değerler.
enum Constants {
    static let defaultOnThreshold = 80
    static let defaultOffThreshold = 100
    static let defaultInterval = 300
}
