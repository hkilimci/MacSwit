import SwiftUI

/// TP-Link (Kasa) specific settings fields for the plug edit sheet.
///
/// Each provider brand has its own fields view. This one is shown when
/// `providerType == .tplink`. See `PlugEditView.providerFieldsView`.
struct TPLinkPlugFieldsView: View {
    @Binding var endpointSelection: String
    @Binding var customEndpoint: String
    @Binding var email: String
    @Binding var password: String
    @Binding var deviceId: String

    var body: some View {
        // Region card
        SettingsCard {
            VStack(alignment: .leading, spacing: 16) {
                SettingsRow(
                    icon: "globe",
                    iconColor: .teal,
                    title: "Region",
                    description: "Select your TP-Link cloud region"
                ) {
                    Picker("", selection: $endpointSelection) {
                        ForEach(TPLinkEndpoint.presets) { endpoint in
                            Text(endpoint.name).tag(endpoint.id)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }

                if endpointSelection == TPLinkEndpoint.custom.id {
                    TextField("Custom host (e.g. wap.tplinkcloud.com)", text: $customEndpoint)
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
                        label: "Email",
                        placeholder: "Your TP-Link account email",
                        text: $email,
                        isSecure: false
                    )

                    CredentialField(
                        label: "Password",
                        placeholder: "Your TP-Link account password",
                        text: $password,
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

                CredentialField(
                    label: "Device ID",
                    placeholder: "Your Kasa smart plug Device ID",
                    text: $deviceId,
                    isSecure: false
                )
            }
        }
    }
}
