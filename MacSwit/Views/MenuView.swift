import SwiftUI
import AppKit

/// Menu bar popup view.
///
/// Shows battery percentage, threshold indicators, status message,
/// active plug selector, and action buttons (enable/disable, settings, quit).
struct MenuView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openSettings) private var openSettings

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private var batteryColor: Color {
        guard appState.mode == .threshold else { return .blue }
        let percent = appState.batteryPercent
        if percent <= appState.onThreshold { return .red }
        else if percent >= appState.offThreshold { return .green }
        else { return .orange }
    }

    private var statusIcon: String {
        guard appState.mode == .threshold else { return "power" }
        let percent = appState.batteryPercent
        if percent <= appState.onThreshold { return "bolt.fill" }
        else if percent >= appState.offThreshold { return "bolt.slash.fill" }
        else { return "bolt.badge.clock.fill" }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with battery visualization
            VStack(spacing: 16) {
                // Battery icon
                BatteryIcon(percent: appState.batteryPercent, color: batteryColor)

                // Threshold indicators or event mode label
                if appState.mode == .threshold {
                    HStack(spacing: 24) {
                        ThresholdIndicator(
                            label: "Charge at",
                            value: appState.onThreshold,
                            icon: "bolt.fill",
                            color: .red
                        )
                        ThresholdIndicator(
                            label: "Stop at",
                            value: appState.offThreshold,
                            icon: "bolt.slash.fill",
                            color: .green
                        )
                    }
                } else {
                    Label("Event-Based Mode", systemImage: "power")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                }

                // Status badge
                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(batteryColor)

                    Text(appState.statusMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(batteryColor.opacity(0.15))
                //.clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Last action info
            VStack(spacing: 4) {
                if !appState.lastActionMessage.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(appState.lastActionMessage)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                if let date = appState.lastCheckDate {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Checked at \(dateFormatter.string(from: date))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, 16)
                .padding(.bottom,6)

            // Action buttons
            VStack(spacing: 4) {

                if appState.plugStore.plugs.count > 1 {
                    HStack(spacing: 12) {
                        Image(systemName: "powerplug")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Picker("", selection: Binding(
                            get: { appState.plugStore.activePlugId },
                            set: { id in
                                if let id { appState.plugStore.setActive(id) }
                            }
                        )) {
                            ForEach(appState.plugStore.plugs) { plug in
                                Text(plug.name).tag(Optional(plug.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                } else if let plugName = appState.activePlugName {
                    HStack(spacing: 12) {
                        Image(systemName: "powerplug")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(plugName)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                MenuToggleButton(
                    title: appState.appEnabled ? "Enabled" : "Disabled",
                    icon: appState.appEnabled ? "bolt.circle.fill" : "bolt.slash.circle",
                    isOn: appState.appEnabled,
                    color: appState.appEnabled ? .green : .gray
                ) {
                    appState.appEnabled.toggle()
                }

                MenuButton(title: "Settings", icon: "gearshape") {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                    // Bring Settings window to front if already open
                    DispatchQueue.main.async {
                        for window in NSApp.windows where window.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" {
                            window.makeKeyAndOrderFront(nil)
                        }
                    }
                }

                MenuButton(title: "Quit", icon: "power") {
                    NSApp.terminate(nil)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
        }
        .frame(width: 260)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Supporting Views

/// Visual battery icon that displays the current charge percentage.
struct BatteryIcon: View {
    let percent: Int
    let color: Color

    private let bodyWidth: CGFloat = 100
    private let bodyHeight: CGFloat = 44
    private let cornerRadius: CGFloat = 8
    private let borderWidth: CGFloat = 2.5
    private let capWidth: CGFloat = 6
    private let capHeight: CGFloat = 18
    private let capRadius: CGFloat = 3
    private let inset: CGFloat = 3.5

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                // Body outline
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.primary.opacity(0.25), lineWidth: borderWidth)
                    .frame(width: bodyWidth, height: bodyHeight)

                // Fill level
                let fillWidth = max(0, (bodyWidth - inset * 2) * CGFloat(percent) / 100)
                RoundedRectangle(cornerRadius: cornerRadius - inset)
                    .fill(color)
                    .frame(width: fillWidth, height: bodyHeight - inset * 2)
                    .padding(.leading, inset)
                    .animation(.easeInOut(duration: 0.5), value: percent)

                // Percentage label
                Text("\(percent)%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .frame(width: bodyWidth, height: bodyHeight)
            }

            // Terminal cap
            RoundedRectangle(cornerRadius: capRadius)
                .fill(Color.primary.opacity(0.25))
                .frame(width: capWidth, height: capHeight)
                .padding(.leading, 2)
        }
    }
}

/// Displays a threshold value (e.g. "Charge at 80%") with an icon and label.
struct ThresholdIndicator: View {
    let label: String
    let value: Int
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(color)
                Text("\(value)%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

/// Standard action button in the menu popup.
struct MenuButton: View {
    let title: String
    let icon: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MenuButtonLabel(title: title, icon: icon, isLoading: isLoading)
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

/// Hover-enabled label view for `MenuButton`.
struct MenuButtonLabel: View {
    let title: String
    let icon: String
    var isLoading: Bool = false

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
            }
            Text(title)
                .font(.system(size: 13, weight: .medium))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color.primary.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

/// Menu toggle button with on/off state (e.g. "Enabled" / "Disabled").
struct MenuToggleButton: View {
    let title: String
    let icon: String
    let isOn: Bool
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? Color.primary.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
