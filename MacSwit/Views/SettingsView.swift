import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    @AppStorage(SettingsKey.onThreshold) private var onThreshold = Constants.defaultOnThreshold
    @AppStorage(SettingsKey.offThreshold) private var offThreshold = Constants.defaultOffThreshold
    @AppStorage(SettingsKey.intervalSec) private var intervalSec = Constants.defaultInterval
    @AppStorage(SettingsKey.startAtLogin) private var startAtLogin = false
    @AppStorage(ProviderSettingsKeys.selectedProvider) private var selectedProviderRaw = ProviderType.tuya.rawValue

    @State private var selectedTab = 0

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
        VStack(spacing: 0) {
            // Battery visualization header
            VStack(spacing: 16) {
                BatteryRangeView(onThreshold: onThreshold, offThreshold: offThreshold)
                    .frame(height: 60)
                    .padding(.horizontal, 24)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(Color.primary.opacity(0.03))

            // Controls
            VStack(spacing: 20) {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsRow(
                            icon: "bolt.fill",
                            iconColor: .red,
                            title: "Start charging at",
                            description: "Turn the plug ON when battery drops to this level"
                        ) {
                            HStack(spacing: 8) {
                                Slider(value: .init(
                                    get: { Double(onThreshold) },
                                    set: { newValue in
                                        let clamped = min(Int(newValue), offThreshold - 5)
                                        onThreshold = max(5, clamped)
                                    }
                                ), in: 5...95)
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
                                Slider(value: .init(
                                    get: { Double(offThreshold) },
                                    set: { newValue in
                                        let clamped = max(Int(newValue), onThreshold + 5)
                                        offThreshold = min(100, clamped)
                                    }
                                ), in: 10...100)
                                .frame(width: 120)

                                Text("\(offThreshold)%")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .frame(width: 40)
                            }
                        }
                    }
                }

                SettingsCard {
                    SettingsRow(
                        icon: "clock",
                        iconColor: .blue,
                        title: "Check interval",
                        description: "How often to check battery level"
                    ) {
                        Picker("", selection: $intervalSec) {
                            Text("1 min").tag(60)
                            Text("2 min").tag(120)
                            Text("5 min").tag(300)
                            Text("10 min").tag(600)
                            Text("15 min").tag(900)
                            Text("30 min").tag(1800)
                        }
                        .labelsHidden()
                        .frame(width: 100)
                    }
                }
            }
            .padding(24)

            Spacer()
        }
    }

    // MARK: - Smart Plug Tab

    private var smartPlugTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Provider selection
                SettingsCard {
                    SettingsRow(
                        icon: "powerplug",
                        iconColor: .blue,
                        title: "Provider",
                        description: "Select your smart plug provider"
                    ) {
                        Picker("", selection: $selectedProviderRaw) {
                            ForEach(ProviderRegistry.shared.availableProviders) { type in
                                Text(type.displayName).tag(type.rawValue)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                        .onChange(of: selectedProviderRaw) { _, _ in
                            appState.setupProvider()
                        }
                    }
                }

                // Provider-specific settings
                providerSettingsView
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private var providerSettingsView: some View {
        switch ProviderType(rawValue: selectedProviderRaw) ?? .tuya {
        case .tuya:
            if let provider = ProviderRegistry.shared.provider(for: .tuya) as? TuyaProvider {
                TuyaSettingsView(provider: provider)
            }
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        VStack(spacing: 20) {
            SettingsCard {
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

            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MacSwit")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Smart battery management for your Mac")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("v1.0")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            Spacer()
        }
        .padding(24)
    }
}

// MARK: - Supporting Views

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
