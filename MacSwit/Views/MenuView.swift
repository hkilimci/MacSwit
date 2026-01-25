import SwiftUI
import AppKit

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
        let percent = appState.batteryPercent
        if percent <= appState.onThreshold {
            return .red
        } else if percent >= appState.offThreshold {
            return .green
        } else {
            return .orange
        }
    }

    private var statusIcon: String {
        let percent = appState.batteryPercent
        if percent <= appState.onThreshold {
            return "bolt.fill"
        } else if percent >= appState.offThreshold {
            return "bolt.slash.fill"
        } else {
            return "bolt.badge.clock.fill"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with battery visualization
            VStack(spacing: 16) {
                // Battery ring
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 8)
                        .frame(width: 80, height: 80)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: CGFloat(appState.batteryPercent) / 100)
                        .stroke(
                            batteryColor,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: appState.batteryPercent)

                    // Center content
                    VStack(spacing: 2) {
                        Text("\(appState.batteryPercent)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("%")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                // Status badge
                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(batteryColor)

                    Text(appState.statusMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(batteryColor.opacity(0.15))
                .clipShape(Capsule())
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Threshold indicators
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
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 16)

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

            // Action buttons
            VStack(spacing: 4) {
                MenuButton(
                    title: appState.isChecking ? "Checking…" : "Check Now",
                    icon: "arrow.clockwise",
                    isLoading: appState.isChecking
                ) {
                    appState.manualCheck()
                }
                .disabled(appState.isChecking)

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
