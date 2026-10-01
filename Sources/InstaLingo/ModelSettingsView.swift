import Foundation
import LookupCore
import SwiftUI

/// Model picker and the user's own models, shown inside the Lookup source form.
struct ModelSettingsSections: View {
    private enum EditorTarget: Identifiable {
        case add
        case edit(CustomModel)

        var id: String {
            switch self {
            case .add: "add"
            case .edit(let model): model.id.uuidString
            }
        }
    }

    @Bindable var configuration: LookupModelConfiguration
    let strings: UIStrings

    @State private var editorTarget: EditorTarget?
    @State private var pendingDeletion: CustomModel?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            Section {
                Picker(strings.modelPicker, selection: $configuration.selection) {
                    Section(strings.builtInModels) {
                        ForEach(GroqModel.allCases) { model in
                            Text(model.displayName).tag(LookupModelSelection.builtIn(model))
                        }
                    }
                    if !configuration.customModels.isEmpty {
                        Section(strings.yourModels) {
                            ForEach(configuration.customModels) { model in
                                Text(model.name).tag(LookupModelSelection.custom(model.id))
                            }
                        }
                    }
                }

                if case .builtIn(let model) = configuration.selection, model.isEffortSelectable {
                    Picker(strings.reasoningEffort, selection: $configuration.reasoningEffort) {
                        ForEach(model.supportedEfforts) { effort in
                            Text(strings.reasoningEffortName(effort)).tag(effort)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text(strings.modelSettings)
            } footer: {
                Text(disclosure)
            }

            Section {
                ForEach(configuration.customModels) { model in
                    CustomModelRow(
                        model: model,
                        hasKey: configuration.hasAPIKey(for: model.id),
                        strings: strings,
                        edit: { editorTarget = .edit(model) },
                        delete: { pendingDeletion = model }
                    )
                }

                Button(strings.addModel) { editorTarget = .add }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            } header: {
                Text(strings.yourModels)
            } footer: {
                if configuration.customModels.isEmpty {
                    Text(strings.noCustomModels)
                }
            }
        }
        .sheet(item: $editorTarget) { target in
            CustomModelEditor(configuration: configuration, strings: strings, existing: existingModel(for: target))
        }
        .confirmationDialog(
            strings.deleteModelConfirmation,
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { model in
            Button(strings.deleteModel, role: .destructive) { delete(model) }
            Button(strings.cancel, role: .cancel) {}
        } message: { model in
            Text(model.name)
        }
    }

    private var disclosure: String {
        if let model = configuration.selectedCustomModel {
            return strings.customDisclosure(host: model.baseURL.host() ?? model.baseURL.absoluteString, model: model.modelID)
        }
        if case .builtIn(let model) = configuration.selection {
            return strings.builtInDisclosure(model: model)
        }
        return strings.builtInDisclosure(model: .gptOSS20B)
    }

    private func existingModel(for target: EditorTarget) -> CustomModel? {
        if case .edit(let model) = target { return model }
        return nil
    }

    private func delete(_ model: CustomModel) {
        do {
            try configuration.deleteCustomModel(id: model.id)
            errorMessage = nil
        } catch {
            errorMessage = strings.errorMessage(error.localizedDescription)
        }
    }
}

private struct CustomModelRow: View {
    let model: CustomModel
    let hasKey: Bool
    let strings: UIStrings
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(model.name)
                    if hasKey {
                        Image(systemName: "key.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help(strings.modelHasKey)
                            .accessibilityLabel(strings.modelHasKey)
                    }
                }
                Text("\(model.baseURL.host() ?? model.baseURL.absoluteString) · \(model.modelID)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button(strings.editModel, action: edit)
            Button(strings.deleteModel, role: .destructive, action: delete)
        }
    }
}

/// Adds or edits one OpenAI-compatible endpoint.
private struct CustomModelEditor: View {
    private enum Field: Hashable {
        case apiKey
    }

    let configuration: LookupModelConfiguration
    let strings: UIStrings
    let existing: CustomModel?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var baseURL: String
    @State private var modelID: String
    @State private var apiKey = ""
    @State private var removesKey = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    init(configuration: LookupModelConfiguration, strings: UIStrings, existing: CustomModel?) {
        self.configuration = configuration
        self.strings = strings
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _baseURL = State(initialValue: existing?.baseURL.absoluteString ?? "")
        _modelID = State(initialValue: existing?.modelID ?? "")
    }

    private var hasSavedKey: Bool {
        guard let existing else { return false }
        return configuration.hasAPIKey(for: existing.id) && !removesKey
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(existing == nil ? strings.addModelTitle : strings.editModelTitle)
                .font(.headline)
                .padding([.horizontal, .top], 20)
            Form {
                Section {
                    TextField(strings.modelName, text: $name, prompt: Text("OpenAI"))
                    TextField(strings.modelBaseURL, text: $baseURL, prompt: Text("https://api.openai.com/v1"))
                        .textContentType(.URL)
                    TextField(strings.modelID, text: $modelID, prompt: Text("gpt-4o-mini"))
                }

                Section {
                    HStack {
                        SecureField(strings.apiKeyOptional, text: $apiKey)
                            .textContentType(.password)
                            .focused($focusedField, equals: .apiKey)
                            .accessibilityLabel(strings.apiKeyOptional)

                        PasteButton(payloadType: String.self) { strings in
                            apiKey = strings.first ?? ""
                            removesKey = false
                            focusedField = .apiKey
                        }
                        .accessibilityLabel(strings.pasteKey)
                    }

                    if hasSavedKey {
                        HStack {
                            Label(strings.keepSavedKey, systemImage: "key.fill")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button(strings.removeKey, role: .destructive) {
                                apiKey = ""
                                removesKey = true
                            }
                        }
                    }
                } footer: {
                    Text(strings.apiKeyLocalHint)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button(strings.cancel, role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(strings.saveModel, action: save)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 440)
    }

    private func save() {
        do {
            let model = try CustomModel(
                id: existing?.id ?? UUID(),
                name: name,
                baseURLString: baseURL,
                modelID: modelID
            )
            let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if existing == nil {
                try configuration.addCustomModel(model, apiKey: trimmedKey.isEmpty ? nil : trimmedKey)
                configuration.selection = .custom(model.id)
            } else {
                // nil keeps the saved key; "" removes it.
                let key: String? = !trimmedKey.isEmpty ? trimmedKey : (removesKey ? "" : nil)
                try configuration.updateCustomModel(model, apiKey: key)
            }
            dismiss()
        } catch {
            errorMessage = strings.errorMessage(error.localizedDescription)
        }
    }
}
