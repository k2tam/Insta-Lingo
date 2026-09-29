import Foundation
import LookupCore
import SwiftUI

/// Groq model and API key sections, shown inside the Lookup source form.
struct GroqSettingsSections: View {
    private enum Field: Hashable {
        case apiKey
    }

    @Bindable var configuration: GroqConfiguration
    let strings: UIStrings

    @State private var draftKey = ""
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    var body: some View {
        Group {
            Section {
                Picker(strings.groqModel, selection: $configuration.model) {
                    ForEach(GroqModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }

                if !configuration.model.supportedEfforts.isEmpty {
                    Picker(strings.reasoningEffort, selection: $configuration.reasoningEffort) {
                        ForEach(configuration.model.supportedEfforts) { effort in
                            Text(strings.reasoningEffortName(effort)).tag(effort)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text(strings.modelSettings)
            } footer: {
                Text(strings.groqDisclosure(model: configuration.model))
            }

            Section(strings.groqAPIKey) {
                HStack {
                    SecureField(strings.groqAPIKey, text: $draftKey)
                        .textContentType(.password)
                        .focused($focusedField, equals: .apiKey)
                        .accessibilityLabel(strings.groqAPIKey)

                    PasteButton(payloadType: String.self) { strings in
                        draftKey = strings.first ?? ""
                        focusedField = .apiKey
                    }
                    .accessibilityLabel(strings.pasteKey)
                }

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
                        Spacer()
                        Label(strings.apiKeySaved, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
