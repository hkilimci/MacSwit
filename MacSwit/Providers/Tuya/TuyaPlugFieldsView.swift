import SwiftUI

/// Tuya-specific settings fields for the plug edit sheet.
///
/// Each provider brand has its own fields view. This one is shown when
/// `providerType == .tuya`. See `PlugEditView.providerFieldsView`.
struct TuyaPlugFieldsView: View {
    @Binding var endpointSelection: String
    @Binding var customEndpoint: String
    @Binding var accessId: String
    @Binding var accessSecret: String
    @Binding var deviceId: String
    @Binding var dpCode: String

    var body: some View {
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
                }

                if endpointSelection == TuyaEndpoint.custom.id {
                    TextField("Custom host (e.g. openapi.tuyaeu.com)", text: $customEndpoint)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
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

                    CredentialField(
                        label: "Access Secret",
                        placeholder: "Your Tuya Access Secret",
                        text: $accessSecret,
                        isSecure: true
                    )
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

                    CredentialField(
                        label: "DP Code",
                        placeholder: "switch_1",
                        text: $dpCode,
                        isSecure: false
                    )
                }
            }
        }
    }
}
