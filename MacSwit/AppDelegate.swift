import AppKit

/// Application lifecycle delegate.
///
/// Shutdown path (in priority order):
///
/// 1. **`willSleepNotification`** — fire-and-forget OFF when the system sleeps.
/// 2. **`willPowerOffNotification`** — synchronous OFF (RunLoop-spin, 8 s window,
///    one retry). Fixes the `applicationShouldTerminate` race via `ShutdownState`.
/// 3. **`applicationShouldTerminate`** — async `.terminateLater` path for normal
///    quit. Returns `.terminateNow` immediately when work is already `.finished`.
class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?

    // MARK: - State

    private enum ShutdownState {
        /// No shutdown work has started.
        case idle
        /// Command dispatched; waiting for reply or timeout.
        case inProgress
        /// Command completed (or timed out). Safe to return `.terminateNow`.
        case finished
    }

    private var shutdownState: ShutdownState = .idle
    /// Set when `applicationShouldTerminate` fires while state is `.inProgress`.
    private var pendingTerminationReply = false

    private var powerOffObserver: Any?
    private var sleepObserver: Any?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        powerOffObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willPowerOffNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.sendShutdownCommandSynchronously(reason: "shutdown")
        }

        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.sendShutdownCommandForSleep()
        }
    }

    deinit {
        if let observer = powerOffObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Synchronous path (willPowerOffNotification)

    /// Sends the shutdown command blocking the calling thread (max 8 s).
    ///
    /// Uses RunLoop spinning so that the @MainActor Task can execute on the
    /// same thread. `applicationShouldTerminate` may be delivered during the
    /// spin — we return `.terminateLater` there and set `pendingTerminationReply`
    /// so `NSApp.reply` is called once the spin completes. When the spin exits
    /// after work is done we transition to `.finished` so any subsequent
    /// `applicationShouldTerminate` call can return `.terminateNow` directly.
    private func sendShutdownCommandSynchronously(reason: String) {
        guard shutdownState == .idle,
              let appState = appState,
              appState.shouldSendOffOnShutdown,
              appState.providerConfigured else { return }

        shutdownState = .inProgress
        var done = false
        Task { @MainActor in
            await appState.sendShutdownCommand(reason: reason)
            done = true
        }
        let deadline = Date(timeIntervalSinceNow: 8)
        while !done && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }

        if !done {
            appState.logShutdownTimeout(reason: reason)
        }

        shutdownState = .finished

        if pendingTerminationReply {
            NSApp.reply(toApplicationShouldTerminate: true)
        }
    }

    // MARK: - Fire-and-forget path (willSleepNotification)

    /// Sends the OFF command without blocking. Best-effort only — the
    /// pre-warmed token makes completion before sleep likely.
    private func sendShutdownCommandForSleep() {
        guard let appState = appState,
              appState.shouldSendOffOnShutdown,
              appState.providerConfigured else { return }

        Task { @MainActor in
            await appState.sendShutdownCommand(reason: "sleep")
        }
    }

    // MARK: - applicationShouldTerminate (normal quit)

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        switch shutdownState {
        case .finished:
            // Synchronous path already completed — terminate immediately.
            return .terminateNow

        case .inProgress:
            // RunLoop spin is still running on this thread. Signal that we
            // need to reply when the spin exits; it will call NSApp.reply.
            pendingTerminationReply = true
            return .terminateLater

        case .idle:
            break
        }

        guard let appState = appState,
              appState.shouldSendOffOnShutdown,
              appState.providerConfigured else {
            return .terminateNow
        }

        shutdownState = .inProgress

        let timeoutItem = DispatchWorkItem { [weak self] in
            self?.appState?.logShutdownTimeout(reason: "quit")
            self?.shutdownState = .finished
            NSApp.reply(toApplicationShouldTerminate: true)
        }

        Task { [weak self] in
            await self?.appState?.sendShutdownCommand(reason: "quit")
            timeoutItem.cancel()
            await MainActor.run {
                self?.shutdownState = .finished
                NSApp.reply(toApplicationShouldTerminate: true)
            }
        }

        // 8-second safety valve in case the network call hangs.
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeoutItem)

        return .terminateLater
    }
}
