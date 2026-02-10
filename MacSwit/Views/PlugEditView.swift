import SwiftUI

/// Form for adding a new plug or editing an existing one.
///
/// Contains name, provider selection, provider-specific fields (Tuya
/// credentials, etc.), and a connection test section. On save, writes
/// the configuration to `PlugStore` and credentials to the Keychain.
struct PlugEditView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let existingConfig: PlugConfig?

    // Draft config holds all editable fields
    @State private var draft: PlugConfig
    @State private var accessId: String = ""
    @State private var accessSecret: String = ""

    // Test state
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

    private var isEditing: Bool { existingConfig != nil }

    init(existingConfig: PlugConfig?) {
        self.existingConfig = existingConfig
        _draft = State(initialValue: existingConfig ?? PlugConfig())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Name card
                SettingsCard {
                    CredentialField(
                        label: "Plug Name",
                        placeholder: "e.g. Office Plug",
                        text: $draft.name,
                        isSecure: false
                    )
                }

                // Provider picker (appears automatically when >1 provider exists)
                if ProviderType.allCases.count > 1 {
                    SettingsCard {
                        SettingsRow(
                            icon: "powerplug",
                            iconColor: .blue,
                            title: "Provider",
                            description: "Select the smart plug brand"
                        ) {
                            Picker("", selection: $draft.providerType) {
                                ForEach(ProviderType.allCases) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 140)
                        }
                    }
                }

                // Provider-specific fields
                providerFieldsView

                // Test card (generic -- works for any provider via PlugProviding)
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

                // Action buttons
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button(isEditing ? "Save" : "Add Plug") {
                        savePlug()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(24)
        }
        .frame(width: 480, height: 580)
        .onAppear {
            if let config = existingConfig {
                accessId = appState.plugStore.readAccessId(for: config)
                accessSecret = appState.plugStore.readSecret(for: config)
            }
        }
    }

    // MARK: - Provider-specific fields

    /// Switches on `providerType` to show the correct brand-specific settings.
    ///
    /// **To add a new provider**, add a case here pointing to your new fields view.
    @ViewBuilder
    private var providerFieldsView: some View {
        switch draft.providerType {
        case .tuya:
            TuyaPlugFieldsView(
                endpointSelection: $draft.tuyaEndpointSelection,
                customEndpoint: $draft.tuyaCustomEndpoint,
                accessId: $accessId,
                accessSecret: $accessSecret,
                deviceId: $draft.tuyaDeviceId,
                dpCode: $draft.tuyaDpCode
            )
        // case .meross:
        //     MerossPlugFieldsView(...)
        }
    }

    // MARK: - Actions

    private func makeTestController() -> any PlugProviding {
        PlugProviderFactory.make(config: draft, accessId: accessId, accessSecret: accessSecret)
    }

    private func savePlug() {
        var config = draft
        config.name = config.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if config.tuyaDpCode.isEmpty { config.tuyaDpCode = "switch_1" }

        do {
            try appState.plugStore.saveAccessId(accessId, for: config)
            try appState.plugStore.saveSecret(accessSecret, for: config)
        } catch {
            testStatus = "Failed to save credentials: \(error.localizedDescription)"
            testStatusType = .error
            return
        }

        if isEditing {
            appState.plugStore.update(config)
        } else {
            appState.plugStore.add(config)
        }

        // Rebuild the controller if this is the active plug
        if appState.plugStore.activePlugId == config.id {
            appState.setupController()
        }

        dismiss()
    }

    private func runCommandTest(value: Bool) {
        isTestingCommand = true
        testStatus = "Sending command..."
        testStatusType = .info
        Task {
            defer { isTestingCommand = false }
            let controller = makeTestController()
            do {
                try await controller.sendCommand(value: value)
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
            let controller = makeTestController()
            do {
                try await controller.testConnection()
                testStatus = "Token verified successfully"
                testStatusType = .success
            } catch {
                testStatus = error.localizedDescription
                testStatusType = .error
            }
        }
    }
}
