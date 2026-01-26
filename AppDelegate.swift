import AppKit

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

        // 3 saniye timeout - bundan sonra zorla kapat
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            NSApp.reply(toApplicationShouldTerminate: true)
        }

        return .terminateLater
    }
}
