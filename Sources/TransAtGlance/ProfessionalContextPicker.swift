import SwiftUI
import LookupCore

struct ProfessionalContextPicker: View {
    let catalog: ProfessionalContextCatalog
    let strings: UIStrings
    @State private var isCreating = false

    var body: some View {
        Menu {
            ForEach(catalog.contexts) { context in
                Button {
                    catalog.select(id: context.id)
                } label: {
                    if context.id == catalog.selectedContext.id {
                        Label(strings.contextName(id: context.id, customName: context.name), systemImage: "checkmark")
                    } else {
                        Text(strings.contextName(id: context.id, customName: context.name))
                    }
                }
            }
            Divider()
            Button(strings.newContext) { isCreating = true }
        } label: {
            Label(strings.contextName(id: catalog.selectedContext.id, customName: catalog.selectedContext.name), systemImage: "square.stack")
        }
        .accessibilityLabel(strings.professionalContextAccessibility(strings.contextName(id: catalog.selectedContext.id, customName: catalog.selectedContext.name)))
        .sheet(isPresented: $isCreating) {
            NewProfessionalContextSheet(catalog: catalog, strings: strings)
        }
    }
}

private struct NewProfessionalContextSheet: View {
    let catalog: ProfessionalContextCatalog
    let strings: UIStrings
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var contextDescription = ""
    @State private var showsValidationError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(strings.newProfessionalContext)
                .font(.headline)
            TextField(strings.contextName, text: $name)
                .accessibilityLabel(strings.contextNameAccessibility)
            TextField(strings.contextDescription, text: $contextDescription)
                .accessibilityLabel(strings.contextDescriptionAccessibility)
            if showsValidationError {
                Text(strings.invalidContext)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button(strings.cancel) { dismiss() }
                Button(strings.addContext) {
                    if catalog.addCustom(name: name, description: contextDescription) {
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
