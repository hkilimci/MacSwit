import AppKit

/// Application lifecycle delegate.
///
/// On quit (`applicationShouldTerminate`), optionally sends a switch-off
/// command to the smart plug based on user settings, with a 3-second
/// timeout for a graceful shutdown.
class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let appState = appState,
              appState.switchOffOnShutdown,
              appState.providerConfigured else {
            return .terminateNow
        }

        Task {
            await appState.sendShutdownCommand()
            await MainActor.run {
                NSApp.reply(toApplicationShouldTerminate: true)
            }
        }

        // 3 seconds timeout - force close after this
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            NSApp.reply(toApplicationShouldTerminate: true)
        }

        return .terminateLater
    }
}
