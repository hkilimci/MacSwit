import Foundation

/// Centralizes all plug state changes with deduplication and a minimum-interval guard.
///
/// - **Deduplication**: skips commands identical to the last sent value.
/// - **Minimum interval**: enforces a cooldown between state changes to prevent rapid toggling.
@MainActor
final class PowerStateManager {
    private(set) var lastSentValue: Bool?
    private var lastSentDate: Date?

    /// Minimum time that must elapse between plug state changes (default 5 minutes).
    let minimumInterval: TimeInterval

    init(minimumInterval: TimeInterval = 5 * 60) {
        self.minimumInterval = minimumInterval
    }

    /// Attempts to send a command through the given controller.
    ///
    /// The command is skipped when:
    /// - The value matches the last sent value (deduplication).
    /// - Less than `minimumInterval` has passed since the last change (debounce).
    ///
    /// - Returns: `true` if the command was sent, `false` if it was skipped.
    @discardableResult
    func send(value: Bool, via controller: any PlugProviding) async throws -> Bool {
        guard lastSentValue != value else { return false }
        if let date = lastSentDate, Date().timeIntervalSince(date) < minimumInterval { return false }
        try await controller.sendCommand(value: value)
        record(value: value)
        return true
    }

    /// Sends the shutdown OFF command, bypassing the minimum interval guard.
    func sendForShutdown(via controller: any PlugProviding) async throws {
        try await controller.sendShutdownCommandFast()
        record(value: false)
    }

    /// Resets tracked state (e.g. after a mode change).
    func reset() {
        lastSentValue = nil
        lastSentDate = nil
    }

    private func record(value: Bool) {
        lastSentValue = value
        lastSentDate = Date()
    }
}
