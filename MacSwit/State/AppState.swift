import Foundation
import SwiftUI
import ServiceManagement
import AppKit
import Combine

@MainActor
final class AppState: ObservableObject {
    enum PlugAction: String {
        case on
        case off

        var value: Bool { self == .on }
        var displayText: String { rawValue.uppercased() }
    }

    enum CheckReason {
        case automatic
        case manual
        case startup
    }

    private struct ActionRecord {
        let action: PlugAction
        let date: Date
    }

    @Published var batteryPercent: Int = 0
    @Published var statusMessage: String = "Ready"
    @Published var lastActionMessage: String = "No actions yet"
    @Published var isChecking: Bool = false
    @Published var lastCheckDate: Date?
    @Published var isPlugOn: Bool = false

    @AppStorage(SettingsKey.onThreshold) var onThreshold: Int = Constants.defaultOnThreshold {
        didSet { _ = validateThresholds() }
    }
    @AppStorage(SettingsKey.offThreshold) var offThreshold: Int = Constants.defaultOffThreshold {
        didSet { _ = validateThresholds() }
    }
    @AppStorage(SettingsKey.intervalSec) var intervalSec: Int = Constants.defaultInterval {
        didSet { restartTimer() }
    }
    @AppStorage(SettingsKey.startAtLogin) var startAtLogin: Bool = false {
        didSet {
            guard !suppressLoginItemSync else { return }
            Task { await syncLoginItem() }
        }
    }
    @AppStorage(SettingsKey.appEnabled) var appEnabled: Bool = true {
        didSet { handleAppEnabledChange() }
    }
    @AppStorage(SettingsKey.switchOffOnShutdown) var switchOffOnShutdown: Bool = false

    // Provider selection
    @AppStorage(ProviderSettingsKeys.selectedProvider) var selectedProviderRaw: String = ProviderType.tuya.rawValue {
        didSet { setupProvider() }
    }

    var selectedProvider: ProviderType {
        get { ProviderType(rawValue: selectedProviderRaw) ?? .tuya }
        set { selectedProviderRaw = newValue.rawValue }
    }

    private let batteryReader = BatteryReader()
    private let hysteresisInterval: TimeInterval = 180
    private var timer: Timer?
    private var lastActionRecord: ActionRecord?
    private var suppressLoginItemSync = false

    // Current provider instance
    private var currentProvider: (any SmartPlugProvider)?

    var loginItemSupported: Bool {
        guard #available(macOS 13.0, *) else { return false }
        return Bundle.main.bundleURL.pathExtension == "app"
    }

    var providerConfigured: Bool {
        currentProvider?.isConfigured ?? false
    }

    var missingConfigurationFields: [String] {
        currentProvider?.missingConfigurationFields ?? ["Provider not selected"]
    }

    init() {
        _ = validateThresholds()
        setupProvider()
        if appEnabled {
            restartTimer()
        }
        Task { await syncLoginItem() }
        performCheck(reason: .startup)
    }

    deinit {
        timer?.invalidate()
    }

    func setupProvider() {
        currentProvider = ProviderRegistry.shared.provider(for: selectedProvider)
        currentProvider?.loadConfiguration()
    }

    func performCheck(reason: CheckReason = .automatic) {
        guard appEnabled else {
            statusMessage = "App disabled"
            return
        }
        guard !isChecking else { return }

        // Check provider configuration first
        guard let provider = currentProvider else {
            statusMessage = "No provider selected"
            return
        }

        if !provider.isConfigured {
            let missing = provider.missingConfigurationFields
            if missing.count == 1 {
                statusMessage = "Missing: \(missing[0])"
            } else {
                statusMessage = "Missing: \(missing.joined(separator: ", "))"
            }
            return
        }

        isChecking = true
        statusMessage = "Checking battery…"

        Task {
            do {
                let percent = try await readBatteryPercent()
                batteryPercent = percent
                lastCheckDate = Date()
                try await evaluateBattery(percent: percent, reason: reason)
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
            }
            isChecking = false
        }
    }

    func manualCheck() {
        performCheck(reason: .manual)
    }

    func testCommand(value: Bool) async throws {
        guard let provider = currentProvider else {
            throw ProviderError.notConfigured
        }
        try await provider.sendCommand(value: value)
    }

    func testToken() async throws {
        guard let provider = currentProvider else {
            throw ProviderError.notConfigured
        }
        try await provider.testConnection()
    }

    func sendShutdownCommand() async {
        guard switchOffOnShutdown else { return }
        guard let provider = currentProvider, provider.isConfigured else { return }

        do {
            try await provider.sendCommand(value: false)
            isPlugOn = false
        } catch {
            // Shutdown sırasında hata olursa sessizce geç
        }
    }
}

// MARK: - Private helpers

private extension AppState {
    func readBatteryPercent() async throws -> Int {
        let reader = batteryReader
        return try await Task.detached(priority: .userInitiated) {
            try await reader.readPercentage()
        }.value
    }

    func evaluateBattery(percent: Int, reason _: CheckReason) async throws {
        guard validateThresholds() else {
            statusMessage = "Fix thresholds (On < Off)."
            return
        }

        let action: PlugAction?
        if percent >= offThreshold {
            action = .off
        } else if percent <= onThreshold {
            action = .on
        } else {
            action = nil
        }

        guard let desiredAction = action else {
            statusMessage = "No action (\(percent)%)"
            return
        }

        if shouldSkip(action: desiredAction) {
            statusMessage = "Skipping (recent \(desiredAction.displayText))"
            return
        }

        guard let provider = currentProvider, provider.isConfigured else {
            statusMessage = "Configure provider in Settings"
            return
        }

        do {
            try await provider.sendCommand(value: desiredAction.value)
            lastActionRecord = ActionRecord(action: desiredAction, date: Date())
            isPlugOn = desiredAction == .on
            lastActionMessage = "Plug \(desiredAction.displayText) at \(percent)%"
            statusMessage = lastActionMessage
        } catch {
            statusMessage = "Command failed: \(error.localizedDescription)"
        }
    }

    func shouldSkip(action: PlugAction) -> Bool {
        guard let record = lastActionRecord, record.action == action else {
            return false
        }
        return Date().timeIntervalSince(record.date) < hysteresisInterval
    }

    func restartTimer() {
        timer?.invalidate()
        let interval = max(60, TimeInterval(intervalSec))
        timer = Timer.scheduledTimer(timeInterval: interval,
                                     target: self,
                                     selector: #selector(handleTimerFired),
                                     userInfo: nil,
                                     repeats: true)
    }

    @objc private func handleTimerFired() {
        performCheck(reason: .automatic)
    }

    @discardableResult
    func validateThresholds() -> Bool {
        if onThreshold < 1 { onThreshold = 1 }
        if offThreshold > 100 { offThreshold = 100 }
        if onThreshold >= offThreshold {
            statusMessage = "On threshold must be less than off threshold."
            return false
        }
        return true
    }

    func syncLoginItem() async {
        guard loginItemSupported else { return }
        do {
            if startAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try await SMAppService.mainApp.unregister()
            }
        } catch {
            handleLoginItemError(error)
        }
    }

    func handleLoginItemError(_ error: Error) {
        let explanatoryMessage: String
        let nsError = error as NSError
        if nsError.domain == "SMAppServiceErrorDomain" {
            // Error codes: 1 = notAuthorized, 2 = notFound, 3 = notRegistered, 4 = notEntitled
            switch nsError.code {
            case 1:
                explanatoryMessage = "Allow MacSwit under System Settings › Login Items."
            case 2, 3, 4:
                explanatoryMessage = "Login item requires running a signed app bundle with the Login Items entitlement."
            default:
                explanatoryMessage = error.localizedDescription
            }
        } else {
            explanatoryMessage = error.localizedDescription
        }
        if startAtLogin {
            suppressLoginItemSync = true
            startAtLogin = false
            suppressLoginItemSync = false
        }
        statusMessage = "Login item error: \(explanatoryMessage)"
    }

    func handleAppEnabledChange() {
        if appEnabled {
            restartTimer()
            statusMessage = "App enabled"
            performCheck(reason: .manual)
        } else {
            timer?.invalidate()
            timer = nil
            statusMessage = "App disabled"
        }
    }
}
