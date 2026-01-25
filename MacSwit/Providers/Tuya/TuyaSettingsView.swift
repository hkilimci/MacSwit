import SwiftUI

struct TuyaSettingsView: View {
    let provider: TuyaProvider

    @AppStorage(TuyaSettingsKey.endpointSelection) private var endpointSelection = TuyaEndpoint.centralEurope.id
    @AppStorage(TuyaSettingsKey.customEndpoint) private var customEndpoint = ""
    @AppStorage(TuyaSettingsKey.accessId) private var accessId = ""
    @AppStorage(TuyaSettingsKey.deviceId) private var deviceId = ""
    @AppStorage(TuyaSettingsKey.dpCode) private var dpCode = "switch_1"

    @State private var accessSecret = ""
    @State private var secretStatus: String = ""
    @State private var testStatus: String = ""
    @State private var testStatusType: StatusType = .info
    @State private var isTestingCommand = false
    @State private var isTestingToken = false

    enum StatusType {
        case info, success, error
        var color: Color {
            switch self {
            case .info: return .secondary
            case .success: return .green
            case .error: return .red
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Region card
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsRow(
                        icon: "globe",
                        iconColor: .purple,
                        title: "Region",
                        description: "Select your Tuya cloud region"
                    ) {
                        Picker("", selection: $endpointSelection) {
                            ForEach(TuyaEndpoint.presets) { endpoint in
                                Text(endpoint.name).tag(endpoint.id)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                        .onChange(of: endpointSelection) { _, _ in
                            provider.loadConfiguration()
                        }
                    }

                    if endpointSelection == TuyaEndpoint.custom.id {
                        TextField("Custom host (e.g. openapi.tuyaeu.com)", text: $customEndpoint)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            .onChange(of: customEndpoint) { _, _ in
                                provider.loadConfiguration()
                            }
                    }
                }
            }

            // Credentials card
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Credentials")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    VStack(alignment: .leading, spacing: 12) {
                        CredentialField(
                            label: "Access ID",
                            placeholder: "Your Tuya Access ID",
                            text: $accessId,
                            isSecure: false
                        )
                        .onChange(of: accessId) { _, _ in
                            provider.loadConfiguration()
                        }

                        CredentialField(
                            label: "Access Secret",
                            placeholder: "Your Tuya Access Secret",
                            text: $accessSecret,
                            isSecure: true
                        )

                        HStack(spacing: 12) {
                            Button(action: saveSecret) {
                                Label("Save Secret", systemImage: "key.fill")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            Button(action: {
                                accessSecret = ""
                                saveSecret()
                            }) {
                                Label("Clear", systemImage: "trash")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            if !secretStatus.isEmpty {
                                Text(secretStatus)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            // Device card
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Device")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    VStack(alignment: .leading, spacing: 12) {
                        CredentialField(
                            label: "Device ID",
                            placeholder: "Your smart plug Device ID",
                            text: $deviceId,
                            isSecure: false
                        )
                        .onChange(of: deviceId) { _, _ in
                            provider.loadConfiguration()
                        }

                        CredentialField(
                            label: "DP Code",
                            placeholder: "switch_1",
                            text: $dpCode,
                            isSecure: false
                        )
                        .onChange(of: dpCode) { _, _ in
                            provider.loadConfiguration()
                        }
                    }
                }
            }

            // Test card
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Connection Test")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    HStack(spacing: 12) {
                        TestButton(
                            title: "Test ON",
                            icon: "bolt.fill",
                            color: .green,
                            isLoading: isTestingCommand
                        ) {
                            runCommandTest(value: true)
                        }

                        TestButton(
                            title: "Test OFF",
                            icon: "bolt.slash.fill",
                            color: .orange,
                            isLoading: isTestingCommand
                        ) {
                            runCommandTest(value: false)
                        }

                        TestButton(
                            title: "Verify Token",
                            icon: "checkmark.shield.fill",
                            color: .blue,
                            isLoading: isTestingToken
                        ) {
                            runTokenTest()
                        }
                    }
                    .disabled(isTestingCommand || isTestingToken)

                    if !testStatus.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: testStatusType == .success ? "checkmark.circle.fill" :
                                    testStatusType == .error ? "xmark.circle.fill" : "info.circle.fill")
                            Text(testStatus)
                                .font(.system(size: 12))
                        }
                        .foregroundColor(testStatusType.color)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .onAppear {
            accessSecret = provider.getAccessSecret()
        }
    }

    private func saveSecret() {
        do {
            try provider.saveAccessSecret(accessSecret)
            secretStatus = "Saved"
        } catch {
            secretStatus = error.localizedDescription
        }
    }

    private func runCommandTest(value: Bool) {
        isTestingCommand = true
        testStatus = "Sending command..."
        testStatusType = .info
        Task {
            defer { isTestingCommand = false }
            do {
                try await provider.sendCommand(value: value)
                testStatus = "Command \(value ? "ON" : "OFF") sent successfully"
                testStatusType = .success
            } catch {
                testStatus = error.localizedDescription
                testStatusType = .error
            }
        }
    }

    private func runTokenTest() {
        isTestingToken = true
        testStatus = "Verifying token..."
        testStatusType = .info
        Task {
            defer { isTestingToken = false }
            do {
                try await provider.testConnection()
                testStatus = "Token verified successfully"
                testStatusType = .success
            } catch {
                testStatus = error.localizedDescription
                testStatusType = .error
            }
        }
    }
}
