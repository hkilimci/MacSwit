import SwiftUI

/// Main settings window.
///
/// Contains three tabs:
/// - **Battery**: Charge start/stop thresholds and check interval
/// - **Smart Plug**: Plug list management (add, edit, delete, set active)
/// - **General**: App enable toggle, login-item, and shutdown behavior
struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    @AppStorage(SettingsKey.onThreshold) private var onThreshold = Constants.defaultOnThreshold
    @AppStorage(SettingsKey.offThreshold) private var offThreshold = Constants.defaultOffThreshold
    @AppStorage(SettingsKey.intervalSec) private var intervalSec = Constants.defaultInterval
    @AppStorage(SettingsKey.startAtLogin) private var startAtLogin = false
    @AppStorage(SettingsKey.appEnabled) private var appEnabled = true
    @AppStorage(SettingsKey.switchOffOnShutdown) private var switchOffOnShutdown = false
    @AppStorage(SettingsKey.mode) private var mode: PowerManagementMode = .threshold
    @AppStorage(SettingsKey.idleGateEnabled) private var idleGateEnabled = false
    @AppStorage(SettingsKey.idleMinutes) private var idleMinutes = Constants.defaultIdleMinutes
    @AppStorage(SettingsKey.plugOnAtStart) private var plugOnAtStart = false
    @State private var selectedTab = 0
    @State private var settingsTab: PowerManagementMode = .threshold
    @State private var showAddPlug = false
    @State private var editingPlug: PlugConfig?

    var body: some View {
        TabView(selection: $selectedTab) {
            batteryTab
                .tabItem {
                    Label("Battery", systemImage: "battery.75percent")
                }
                .tag(0)

            smartPlugTab
                .tabItem {
                    Label("Smart Plug", systemImage: "powerplug")
                }
                .tag(1)

            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(2)
        }
        .frame(width: 480, height: 480)
    }

    // MARK: - Battery Tab

    private var batteryTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Active mode selector — controls which mode is actually running
                SettingsCard {
                    SettingsRow(
                        icon: "slider.horizontal.3",
                        iconColor: .purple,
                        title: "Active Mode",
                        description: mode.modeDescription
                    ) {
                        Picker("", selection: $mode) {
                            ForEach(PowerManagementMode.allCases) { m in
                                Text(m.displayName).tag(m)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 130)
                    }
                }

                // Startup & shutdown — applies regardless of mode
                SettingsCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsRow(
                            icon: "bolt.circle.fill",
                            iconColor: .green,
                            title: "Turn plug ON at startup",
                            description: "Send switch ON command when MacSwit launches"
                        ) {
                            Toggle("", isOn: mode == .event ? .constant(true) : $plugOnAtStart)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .disabled(mode == .event)
                        }

                        Divider()

                        SettingsRow(
                            icon: "moon.zzz.fill",
                            iconColor: .orange,
                            title: "Turn plug OFF on shutdown",
                            description: "Send switch OFF command when Mac shuts down"
                        ) {
                            Toggle(
                                "", isOn: mode == .event ? .constant(true) : $switchOffOnShutdown
                            )
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .disabled(mode == .event)
                        }
                    }
                }

                // Mode settings tabs — navigate to configure each mode independently
                Picker("", selection: $settingsTab) {
                    ForEach(PowerManagementMode.allCases) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                modeSettingsContent

                Spacer(minLength: 16)
            }
            .padding(24)
        }
        .onAppear { settingsTab = mode }
    }

    @ViewBuilder
    private var modeSettingsContent: some View {
        switch settingsTab {
        case .threshold:
            thresholdSettingsContent
        case .event:
            eventSettingsContent
        }
    }

    private var thresholdSettingsContent: some View {
        VStack(spacing: 16) {
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsRow(
                        icon: "bolt.fill",
                        iconColor: .red,
                        title: "Start charging at",
                        description: "Turn the plug ON when battery drops to this level"
                    ) {
                        HStack(spacing: 8) {
                            Slider(
                                value: .init(
                                    get: { Double(onThreshold) },
                                    set: { newValue in
                                        let clamped = min(Int(newValue), offThreshold - 5)
                                        onThreshold = max(5, clamped)
                                    }
                                ), in: 5...95
                            )
                            .frame(width: 120)

                            Text("\(onThreshold)%")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .frame(width: 40)
                        }
                    }

                    Divider()

                    SettingsRow(
                        icon: "bolt.slash.fill",
                        iconColor: .green,
                        title: "Stop charging at",
                        description: "Turn the plug OFF when battery reaches this level"
                    ) {
                        HStack(spacing: 8) {
                            Slider(
                                value: .init(
                                    get: { Double(offThreshold) },
                                    set: { newValue in
                                        let clamped = max(Int(newValue), onThreshold + 5)
                                        offThreshold = min(100, clamped)
                                    }
                                ), in: 10...100
                            )
                            .frame(width: 120)

                            Text("\(offThreshold)%")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .frame(width: 40)
                        }
                    }

                    Divider()

                    SettingsRow(
                        icon: "clock",
                        iconColor: .blue,
                        title: "Check interval",
                        description: "How often to check battery level"
                    ) {
                        Picker("", selection: $intervalSec) {
                            Text("1 min").tag(60)
                            Text("5 mins").tag(300)
                            Text("15 mins").tag(900)
                            Text("30 mins").tag(1800)
                            Text("1 hour").tag(3600)
                        }
                        .labelsHidden()
                        .frame(width: 100)
                    }

                    Divider()

                    SettingsRow(
                        icon: "moon.zzz.fill",
                        iconColor: .indigo,
                        title: "Only turn OFF when idle",
                        description: "Wait until the system is idle before cutting power"
                    ) {
                        Toggle("", isOn: $idleGateEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    if idleGateEnabled {
                        SettingsRow(
                            icon: "timer",
                            iconColor: .indigo,
                            title: "Idle time required",
                            description:
                                "How long the system must be idle before the plug turns OFF"
                        ) {
                            Picker("", selection: $idleMinutes) {
                                Text("10 min").tag(10)
                                Text("20 min").tag(20)
                                Text("30 min").tag(30)
                                Text("45 min").tag(45)
                                Text("60 min").tag(60)
                            }
                            .labelsHidden()
                            .frame(width: 100)
                        }
                    }
                }
            }
        }
    }

    private var eventSettingsContent: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("No battery monitoring", systemImage: "info.circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Text(
                    "In Event mode the plug is controlled only by the startup and shutdown toggles above. Battery level is not checked."
                )
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Smart Plug Tab

    private var smartPlugTab: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(appState.plugStore.plugs) { plug in
                        PlugRow(
                            plug: plug,
                            isActive: appState.plugStore.activePlugId == plug.id,
                            plugStore: appState.plugStore,
                            onActivate: {
                                appState.plugStore.setActive(plug.id)
                            },
                            onEdit: {
                                editingPlug = plug
                            },
                            onDelete: {
                                appState.plugStore.delete(plug.id)
                            }
                        )
                    }

                    if appState.plugStore.plugs.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "powerplug")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary)
                            Text("No plugs configured")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("Add a smart plug to get started")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                }
                .padding(24)
            }

            Divider()

            HStack {
                Button(action: { showAddPlug = true }) {
                    Label("Add Plug", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .sheet(isPresented: $showAddPlug) {
            PlugEditView(existingConfig: nil)
                .environmentObject(appState)
        }
        .sheet(item: $editingPlug) { plug in
            PlugEditView(existingConfig: plug)
                .environmentObject(appState)
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        VStack(spacing: 20) {
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsRow(
                        icon: "bolt.circle.fill",
                        iconColor: appEnabled ? .green : .gray,
                        title: "Enable MacSwit",
                        description: "Turn on/off automatic battery monitoring and plug control"
                    ) {
                        Toggle("", isOn: $appEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    Divider()

                    SettingsRow(
                        icon: "power",
                        iconColor: .blue,
                        title: "Launch at login",
                        description: appState.loginItemSupported
                            ? "Automatically start MacSwit when you log in"
                            : "Requires a signed .app bundle on macOS 13+"
                    ) {
                        Toggle("", isOn: $startAtLogin)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .disabled(!appState.loginItemSupported)
                    }

                }
            }

            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MacSwit")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Smart plugged battery management for your Mac")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    Divider()

                    // Update banner
                    if let version = appState.updateAvailable, let url = appState.updateURL {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.blue)
                            Text("v\(version) available")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.blue)
                            Spacer()
                            Link("Download", destination: url)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        Divider()
                    }

                    // Check for Updates button
                    HStack(spacing: 8) {
                        TestButton(
                            title: "Check for Updates",
                            icon: "arrow.triangle.2.circlepath",
                            color: .blue,
                            isLoading: appState.isCheckingForUpdates
                        ) {
                            Task { await appState.checkForUpdates() }
                        }
                        Spacer()
                        if !appState.isCheckingForUpdates, let latest = appState.latestReleasedVersion {
                            if appState.updateAvailable != nil {
                                Label("v\(latest) available", systemImage: "arrow.down.circle.fill")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.blue)
                            } else {
                                Label("Up to date · v\(latest)", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.green)
                            }
                        }
                    }

                    Divider()

                    Link(destination: URL(string: "https://www.buymeacoffee.com/hhklmc")!) {
                        SettingsRow(
                            icon: "cup.and.saucer.fill",
                            iconColor: .brown,
                            title: "Buy me a coffee",
                            description: "Support the developer"
                        ) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(24)
    }
}

// MARK: - Supporting Views

/// Rounded card container used in the settings tabs.
struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}

/// Single row in a settings card: icon, title, description, and trailing control.
struct SettingsRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            content
        }
    }
}

/// Credential input field; uses `SecureField` when `isSecure` is true.
struct CredentialField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
        }
    }
}

/// Colored button with loading indicator, used for connection tests.
struct TestButton: View {
    let title: String
    let icon: String
    let color: Color
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

/// Visualizes charge thresholds on a colored bar.
///
/// Red zone: needs charging, orange-green: optimal range, green: full.
struct BatteryRangeView: View {
    let onThreshold: Int
    let offThreshold: Int

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let onPosition = max(0, CGFloat(onThreshold) / 100 * width)
            let offPosition = max(onPosition + 1, CGFloat(offThreshold) / 100 * width)
            let middleWidth = max(0, offPosition - onPosition)
            let endWidth = max(0, width - offPosition)

            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 16)

                // Charging range (red zone - needs charging)
                if onPosition > 0 {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.red.opacity(0.6), .red.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: onPosition, height: 16)
                }

                // Optimal range
                if middleWidth > 0 {
                    RoundedRectangle(cornerRadius: 0)
                        .fill(
                            LinearGradient(
                                colors: [.orange.opacity(0.5), .green.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: middleWidth, height: 16)
                        .offset(x: onPosition)
                }

                // Full zone (stop charging)
                if endWidth > 0 {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.green.opacity(0.3), .green.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: endWidth, height: 16)
                        .offset(x: offPosition)
                }

                // Threshold markers
                ThresholdMarker(label: "\(onThreshold)%", color: .red)
                    .offset(x: max(0, onPosition - 15))

                ThresholdMarker(label: "\(offThreshold)%", color: .green)
                    .offset(x: max(0, offPosition - 15))
            }
        }
    }
}

/// Single row in the plug list; active selection, manual on/off, edit, and delete buttons.
struct PlugRow: View {
    let plug: PlugConfig
    let isActive: Bool
    let plugStore: PlugStore
    let onActivate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isSending = false
    @State private var lastResult: SwitchResult?

    private enum SwitchResult {
        case on, off
        case error(String)
    }

    var body: some View {
        SettingsCard {
            HStack(spacing: 12) {
                Button(action: onActivate) {
                    Image(systemName: isActive ? "largecircle.fill.circle" : "circle")
                        .font(.system(size: 16))
                        .foregroundColor(isActive ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(plug.name)
                        .font(.system(size: 13, weight: .medium))

                    if case .error(let msg) = lastResult {
                        Text(msg)
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                            .lineLimit(1)
                    } else {
                        Text(plug.providerType.displayName)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    // Manual ON/OFF switches
                    switchButton(value: true)
                    switchButton(value: false)

                    Divider()
                        .frame(height: 16)

                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func switchButton(value: Bool) -> some View {
        Button {
            sendCommand(value: value)
        } label: {
            Group {
                if isSending {
                    ProgressView()
                        .scaleEffect(0.45)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: value ? "bolt.fill" : "bolt.slash.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .frame(width: 24, height: 24)
            .background(buttonBackground(for: value))
            .foregroundColor(buttonForeground(for: value))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .disabled(isSending)
    }

    private func buttonBackground(for value: Bool) -> Color {
        switch lastResult {
        case .on where value: return .green.opacity(0.25)
        case .off where !value: return .orange.opacity(0.25)
        default: return Color.primary.opacity(0.06)
        }
    }

    private func buttonForeground(for value: Bool) -> Color {
        switch lastResult {
        case .on where value: return .green
        case .off where !value: return .orange
        default: return .secondary
        }
    }

    private func sendCommand(value: Bool) {
        isSending = true
        lastResult = nil
        Task {
            defer { isSending = false }
            let accessId = plugStore.readAccessId(for: plug)
            let secret = plugStore.readSecret(for: plug)
            let controller = PlugProviderFactory.make(
                config: plug, accessId: accessId, accessSecret: secret)
            do {
                try await controller.sendCommand(value: value)
                lastResult = value ? .on : .off
            } catch {
                lastResult = .error(error.localizedDescription)
            }
        }
    }
}

/// Threshold marker on `BatteryRangeView` (line + circle + label).
struct ThresholdMarker: View {
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(color)

            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 2, height: 24)

            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
    }
}
