import SwiftUI
import LookupCore

struct GeminiSettingsView: View {
    @Bindable var configuration: GeminiConfiguration
    @Bindable var fallbackSettings: GeminiFallbackSettings
    let strings: UIStrings

    @State private var draftKey = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Toggle(strings.enableGemini, isOn: Binding(
                get: { configuration.isEnabled },
                set: { configuration.setEnabled($0) }
            ))

            Text(strings.geminiDisclosure)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker(strings.fallbackSetting, selection: $fallbackSettings.choice) {
                Text(strings.fallbackAsk).tag(GeminiFallbackChoice.ask)
                Text(strings.fallbackAllow).tag(GeminiFallbackChoice.allow)
                Text(strings.fallbackDecline).tag(GeminiFallbackChoice.decline)
            }
            .disabled(!configuration.isEnabled)

            SecureField(strings.geminiAPIKey, text: $draftKey)
                .textContentType(.password)
                .accessibilityLabel(strings.geminiAPIKey)

            HStack {
                Button(strings.saveKey) {
                    do {
                        try configuration.saveAPIKey(draftKey)
                        draftKey = ""
                        errorMessage = nil
                    } catch {
                        errorMessage = strings.errorMessage(error.localizedDescription)
                    }
                }
                .disabled(draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if configuration.hasAPIKey {
                    Button(strings.removeKey, role: .destructive) {
                        do {
                            try configuration.removeAPIKey()
                            errorMessage = nil
                        } catch {
                            errorMessage = strings.errorMessage(error.localizedDescription)
                        }
                    }
                    Text(strings.apiKeySaved)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 450)
        .padding()
    }
}
