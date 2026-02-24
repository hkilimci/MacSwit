import Foundation
import SwiftUI
import ServiceManagement
import Combine
import UserNotifications

// MARK: - Shutdown log

struct ShutdownLogEntry: Codable, Identifiable {
    enum Outcome: String, Codable {
        case attempted, succeeded, error, timeout
    }

    var id: UUID = UUID()
    var date: Date
    var reason: String
    var outcome: Outcome
    var detail: String?
}

/// Central state manager for the application.
///
/// Periodically reads battery level and toggles the smart plug on/off
/// based on configurable thresholds. Handles timer-based automatic checks,
/// command deduplication (same command is not resent until the opposite
/// action occurs), login-item management, and shutdown plug control.
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


    @Published var batteryPercent: Int = 0
    @Published var statusMessage: String = "Ready"
    @Published var lastActionMessage: String = "No actions yet"
    @Published var isChecking: Bool = false
    @Published var lastCheckDate: Date?
    @Published var isPlugOn: Bool = false
    @Published var updateAvailable: String? = nil
    @Published var updateURL: URL? = nil
    @Published var latestReleasedVersion: String? = nil
    @Published var isCheckingForUpdates: Bool = false

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
    @AppStorage(SettingsKey.switchOffOnShutdown) var switchOffOnShutdown: Bool = false {
        didSet { handleSwitchOffOnShutdownChange() }
    }
    @AppStorage(SettingsKey.mode) var mode: PowerManagementMode = .threshold {
        didSet { handleModeChange() }
    }
    @AppStorage(SettingsKey.idleGateEnabled) var idleGateEnabled: Bool = false
    @AppStorage(SettingsKey.idleMinutes) var idleMinutes: Int = Constants.defaultIdleMinutes
    @AppStorage(SettingsKey.plugOnAtStart) var plugOnAtStart: Bool = false

    @Published var shutdownLog: [ShutdownLogEntry] = []

    let plugStore: PlugStore

    private let batteryReader = BatteryReader()
    private let powerStateManager = PowerStateManager()
    private var timer: Timer?
    private var warmTimer: Timer?
    private var suppressLoginItemSync = false
    private var currentController: (any PlugProviding)?
    private var cancellables = Set<AnyCancellable>()

    var loginItemSupported: Bool {
        guard #available(macOS 13.0, *) else { return false }
        return Bundle.main.bundleURL.pathExtension == "app"
    }

    var providerConfigured: Bool {
        currentController?.isConfigured ?? false
    }

    /// Whether the plug should be turned OFF when the system shuts down or sleeps.
    /// Always true for Event mode; controlled by `switchOffOnShutdown` in Threshold and Hybrid modes.
    var shouldSendOffOnShutdown: Bool {
        mode == .event ? true : switchOffOnShutdown
    }

    /// Whether the plug should be turned ON when the app starts.
    /// Always true for Event mode; controlled by `plugOnAtStart` in Threshold and Hybrid modes.
    var shouldPlugOnAtStart: Bool {
        mode == .event ? true : plugOnAtStart
    }

    var activePlugName: String? {
        plugStore.activePlug?.name
    }

    init() {
        plugStore = PlugStore()

        if intervalSec < 60 { intervalSec = 60 }
        _ = validateThresholds()
        setupController()

        // Subscribe to active plug changes to rebuild controller
        plugStore.$activePlugId
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.setupController()
            }
            .store(in: &cancellables)

        // Forward plugStore changes to trigger UI updates
        plugStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        requestNotificationPermission()
        loadShutdownLog()
        restartTimer()
        if switchOffOnShutdown {
            startWarmTimer()
            Task { try? await warmProviderToken() }
        }
        Task { await syncLoginItem() }
        Task { await performLaunchActions() }
        performCheck(reason: .startup)
        Task { await checkForUpdates() }
    }

    deinit {
        timer?.invalidate()
        warmTimer?.invalidate()
    }

    func setupController() {
        guard let plug = plugStore.activePlug else {
            currentController = nil
            return
        }
        let accessId = plugStore.readAccessId(for: plug)
        let secret = plugStore.readSecret(for: plug)
        currentController = PlugProviderFactory.make(config: plug, accessId: accessId, accessSecret: secret)
    }

    func performCheck(reason: CheckReason = .automatic) {
        guard !isChecking else { return }

        guard mode.usesBatteryMonitoring else {
            Task {
                if let percent = try? await readBatteryPercent() {
                    batteryPercent = percent
                    lastCheckDate = Date()
                }
                statusMessage = appEnabled ? "Event mode – awaiting system events" : "App disabled"
            }
            return
        }

        isChecking = true
        statusMessage = appEnabled ? "Checking battery…" : "App disabled"

        Task {
            do {
                let percent = try await readBatteryPercent()
                batteryPercent = percent
                lastCheckDate = Date()

                guard appEnabled else {
                    statusMessage = "App disabled"
                    isChecking = false
                    return
                }

                guard let controller = currentController else {
                    statusMessage = "No plug configured"
                    isChecking = false
                    return
                }

                if !controller.isConfigured {
                    let missing = controller.missingFields
                    if missing.count == 1 {
                        statusMessage = "Missing: \(missing[0])"
                    } else {
                        statusMessage = "Missing: \(missing.joined(separator: ", "))"
                    }
                    isChecking = false
                    return
                }

                try await evaluateBattery(percent: percent, reason: reason)
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
            }
            isChecking = false
        }
    }

    func testToken() async throws {
        guard let controller = currentController else {
            throw ProviderError.notConfigured
        }
        try await controller.testConnection()
    }

    /// Sends the OFF command on the fast shutdown path with one retry.
    /// Logs each attempt and its outcome to `shutdownLog`.
    ///
    /// - Parameter reason: Human-readable trigger context ("shutdown", "quit", "sleep").
    func sendShutdownCommand(reason: String) async {
        guard appEnabled else { return }
        guard shouldSendOffOnShutdown else { return }
        guard let controller = currentController, controller.isConfigured else { return }

        appendShutdownLog(ShutdownLogEntry(date: Date(), reason: reason, outcome: .attempted))

        var lastError: Error?
        for attempt in 1...2 {
            do {
                try await controller.sendShutdownCommandFast()
                isPlugOn = false
                appendShutdownLog(ShutdownLogEntry(date: Date(), reason: reason, outcome: .succeeded))
                return
            } catch {
                lastError = error
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 s before retry
                }
            }
        }
        appendShutdownLog(ShutdownLogEntry(
            date: Date(),
            reason: reason,
            outcome: .error,
            detail: lastError?.localizedDescription
        ))
    }

    /// Appends a `.timeout` log entry. `internal` so `AppDelegate` can call it.
    func logShutdownTimeout(reason: String) {
        appendShutdownLog(ShutdownLogEntry(date: Date(), reason: reason, outcome: .timeout))
    }

    func checkForUpdates() async {
        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true
        defer { isCheckingForUpdates = false }

        do {
            let checker = UpdateChecker()
            if let result = try await checker.check() {
                latestReleasedVersion = result.latestVersion
                if result.isNewer {
                    updateAvailable = result.latestVersion
                    updateURL = result.releaseURL
                } else {
                    updateAvailable = nil
                    updateURL = nil
                }
            }
        } catch {
            // Silently ignore network errors on auto-check
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
        guard let controller = currentController, controller.isConfigured else {
            statusMessage = "Configure plug in Settings"
            return
        }

        guard validateThresholds() else {
            statusMessage = "Fix thresholds (On < Off)."
            return
        }

        let desiredValue = ThresholdStrategy(
            onThreshold: onThreshold,
            offThreshold: offThreshold,
            idleMinutes: idleGateEnabled ? idleMinutes : nil
        ).evaluate(batteryPercent: percent)

        guard let value = desiredValue else {
            statusMessage = "No action (\(percent)%)"
            return
        }

        let sent = try await powerStateManager.send(value: value, via: controller)
        if sent {
            isPlugOn = value
            let action: PlugAction = value ? .on : .off
            lastActionMessage = "Plug \(action.displayText) at \(percent)%"
            statusMessage = lastActionMessage
            postPlugNotification(action: action, percent: percent)
        } else {
            statusMessage = "Skipping (recent \(value ? "ON" : "OFF"))"
        }
    }

    func restartTimer() {
        timer?.invalidate()
        guard mode.usesBatteryMonitoring else {
            timer = nil
            return
        }
        let interval = TimeInterval(intervalSec)
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

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func postPlugNotification(action: PlugAction, percent: Int) {
        let content = UNMutableNotificationContent()
        content.title = "MacSwit"
        content.body = action == .on
            ? "Plug turned ON — battery at \(percent)%"
            : "Plug turned OFF — battery at \(percent)%"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func handleAppEnabledChange() {
        performCheck(reason: .manual)
    }

    func handleModeChange() {
        powerStateManager.reset()
        restartTimer()
        Task { await performLaunchActions() }
        performCheck(reason: .manual)
    }

    /// Turns the plug ON at launch/mode-switch when `shouldPlugOnAtStart` is true.
    func performLaunchActions() async {
        guard shouldPlugOnAtStart, appEnabled else { return }
        guard let controller = currentController, controller.isConfigured else { return }
        do {
            let sent = try await powerStateManager.send(value: true, via: controller)
            if sent {
                isPlugOn = true
                lastActionMessage = "Plug ON (launch)"
                statusMessage = lastActionMessage
            }
        } catch {
            statusMessage = "Launch ON failed: \(error.localizedDescription)"
        }
    }

    func handleSwitchOffOnShutdownChange() {
        if switchOffOnShutdown {
            startWarmTimer()
            Task { try? await warmProviderToken() }
        } else {
            warmTimer?.invalidate()
            warmTimer = nil
        }
    }

    // MARK: - Token warming

    func startWarmTimer() {
        warmTimer?.invalidate()
        warmTimer = Timer.scheduledTimer(
            timeInterval: 20 * 60,
            target: self,
            selector: #selector(handleWarmTimerFired),
            userInfo: nil,
            repeats: true
        )
    }

    @objc func handleWarmTimerFired() {
        Task { try? await warmProviderToken() }
    }

    func warmProviderToken() async throws {
        guard let controller = currentController, controller.isConfigured else { return }
        try await controller.warmToken()
    }

    // MARK: - Shutdown logging

    func loadShutdownLog() {
        guard let data = UserDefaults.standard.data(forKey: SettingsKey.shutdownLog),
              let entries = try? JSONDecoder().decode([ShutdownLogEntry].self, from: data)
        else { return }
        shutdownLog = entries
    }

    func appendShutdownLog(_ entry: ShutdownLogEntry) {
        var log = shutdownLog
        log.append(entry)
        if log.count > 20 { log = Array(log.suffix(20)) }
        shutdownLog = log
        if let data = try? JSONEncoder().encode(log) {
            UserDefaults.standard.set(data, forKey: SettingsKey.shutdownLog)
        }
    }
}
