import SwiftUI
import LookupCore

struct ProfessionalContextPicker: View {
    let catalog: ProfessionalContextCatalog
    let strings: UIStrings
    @State private var isCreating = false
    @State private var isHovered = false

    var body: some View {
        Menu {
            ForEach(catalog.visibleContexts) { context in
                let name = strings.contextName(id: context.id, customName: context.name)
                Toggle(name, isOn: Binding(
                    get: { context.id == catalog.selectedContext.id },
                    set: { _ in catalog.select(id: context.id) }
                ))
                .help(strings.contextDescription(id: context.id, customDescription: context.description))
            }
            Divider()
            Button(strings.newContext, systemImage: "plus") { isCreating = true }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "briefcase")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Text(selectedName)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Theme.control, in: Capsule())
            .overlay {
                Capsule().strokeBorder(Color.white.opacity(isHovered ? 0.25 : 0.12))
            }
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .onHover { isHovered = $0 }
        .help(strings.contextDescription(id: catalog.selectedContext.id, customDescription: catalog.selectedContext.description))
        .accessibilityLabel(strings.professionalContext)
        .accessibilityValue(selectedName)
        .sheet(isPresented: $isCreating) {
            ProfessionalContextEditor(catalog: catalog, strings: strings, context: nil)
        }
    }

    private var selectedName: String {
        strings.contextName(id: catalog.selectedContext.id, customName: catalog.selectedContext.name)
    }
}

struct ProfessionalContextSettingsView: View {
    let catalog: ProfessionalContextCatalog
    let strings: UIStrings
    @State private var isCreating = false
    @State private var editingContext: ProfessionalContext?
    @State private var contextToDelete: ProfessionalContext?

    var body: some View {
        Form {
            Section(strings.professionalContext) {
                Picker(strings.selectedContext, selection: Binding(
                    get: { catalog.selectedContext.id },
                    set: { catalog.select(id: $0) }
                )) {
                    ForEach(catalog.visibleContexts) { context in
                        Text(strings.contextName(id: context.id, customName: context.name))
                            .tag(context.id)
                    }
                }
                Text(strings.contextSelectionHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(catalog.contexts) { context in
                    let displayName = strings.contextName(id: context.id, customName: context.name)
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(displayName)
                                .fontWeight(.medium)
                            Text(strings.contextDescription(id: context.id, customDescription: context.description))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Toggle(strings.showInLookupWindow, isOn: Binding(
                            get: { catalog.visibleContextIDs.contains(context.id) },
                            set: { catalog.setVisible($0, id: context.id) }
                        ))
                        .labelsHidden()
                        .help(strings.showInLookupWindow)
                        .accessibilityLabel("\(strings.showInLookupWindow): \(displayName)")
                        .disabled(catalog.visibleContextIDs.count == 1 && catalog.visibleContextIDs.contains(context.id))
                        Button(strings.editContext) { editingContext = context }
                            .accessibilityLabel("\(strings.editContext): \(displayName)")
                        Button(strings.deleteContext, role: .destructive) {
                            contextToDelete = context
                        }
                        .accessibilityLabel("\(strings.deleteContext): \(displayName)")
                        .disabled(catalog.contexts.count == 1)
                    }
                }
                Button(strings.addContext, systemImage: "plus") { isCreating = true }
            } header: {
                Text(strings.availableContexts)
            } footer: {
                Text(strings.contextVisibilityHint)
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $isCreating) {
            ProfessionalContextEditor(catalog: catalog, strings: strings, context: nil)
        }
        .sheet(item: $editingContext) { context in
            ProfessionalContextEditor(catalog: catalog, strings: strings, context: context)
        }
        .confirmationDialog(
            strings.deleteContextConfirmation,
            isPresented: Binding(
                get: { contextToDelete != nil },
                set: { if !$0 { contextToDelete = nil } }
            )
        ) {
            Button(strings.deleteContext, role: .destructive) {
                if let contextToDelete { catalog.remove(id: contextToDelete.id) }
                contextToDelete = nil
            }
            Button(strings.cancel, role: .cancel) { contextToDelete = nil }
        } message: {
            Text(contextToDelete?.name ?? "")
        }
    }
}

private struct ProfessionalContextEditor: View {
    let catalog: ProfessionalContextCatalog
    let strings: UIStrings
    let context: ProfessionalContext?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var contextDescription: String
    @State private var showsValidationError = false

    init(catalog: ProfessionalContextCatalog, strings: UIStrings, context: ProfessionalContext?) {
        self.catalog = catalog
        self.strings = strings
        self.context = context
        _name = State(initialValue: context.map { strings.contextName(id: $0.id, customName: $0.name) } ?? "")
        _contextDescription = State(initialValue: context.map { strings.contextDescription(id: $0.id, customDescription: $0.description) } ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(context == nil ? strings.newProfessionalContext : strings.editProfessionalContext)
                .font(.headline)
            VStack(alignment: .leading, spacing: 5) {
                Text(strings.contextNameAccessibility)
                TextField(strings.contextName, text: $name)
                    .accessibilityLabel(strings.contextNameAccessibility)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(strings.contextDescriptionAccessibility)
                TextField(strings.contextDescription, text: $contextDescription)
                    .accessibilityLabel(strings.contextDescriptionAccessibility)
            }
            if showsValidationError {
                Text(strings.invalidContext)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button(strings.cancel) { dismiss() }
                Button(context == nil ? strings.addContext : strings.saveContext) {
                    let saved = if let context {
                        catalog.update(id: context.id, name: name, description: contextDescription)
                    } else {
                        catalog.addCustom(name: name, description: contextDescription)
                    }
                    if saved {
                        dismiss()
                    } else {
                        showsValidationError = true
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
