import Foundation

enum SettingsKey {
    static let onThreshold = "MacSwit.onThreshold"
    static let offThreshold = "MacSwit.offThreshold"
    static let intervalSec = "MacSwit.intervalSec"
    static let startAtLogin = "MacSwit.startAtLogin"
}

enum Constants {
    static let defaultOnThreshold = 80
    static let defaultOffThreshold = 100
    static let defaultInterval = 300
}
