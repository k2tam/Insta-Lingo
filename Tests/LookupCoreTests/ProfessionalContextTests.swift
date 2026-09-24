import Foundation
import Testing
@testable import LookupCore

@Test @MainActor
func contextCatalogOffersPresetsAndPersistsCustomSelection() {
    let suite = "ProfessionalContextTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let catalog = ProfessionalContextCatalog(defaults: defaults)
    #expect(catalog.contexts.map(\.name) == ["General", "Software Development", "Swift/iOS"])
    #expect(catalog.selectedContext == .general)

    #expect(catalog.addCustom(name: "  Finance  ", description: "  Investing and accounting terms.  "))
    let selected = catalog.selectedContext
    #expect(selected.name == "Finance")
    #expect(selected.description == "Investing and accounting terms.")

    let reopened = ProfessionalContextCatalog(defaults: defaults)
    #expect(reopened.contexts.count == 4)
    #expect(reopened.selectedContext == selected)
    #expect(reopened.select(id: ProfessionalContext.swiftIOS.id))
    #expect(ProfessionalContextCatalog(defaults: defaults).selectedContext == .swiftIOS)
}

@Test @MainActor
func contextCatalogRejectsEmptyDuplicateAndUnknownContexts() {
    let suite = "ProfessionalContextTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let catalog = ProfessionalContextCatalog(defaults: defaults)
    #expect(!catalog.addCustom(name: " ", description: "A field"))
    #expect(!catalog.addCustom(name: "Law", description: " "))
    #expect(!catalog.addCustom(name: "general", description: "A duplicate"))
    #expect(!catalog.select(id: "missing"))
    #expect(catalog.contexts.count == 3)
    #expect(catalog.selectedContext == .general)
}

@Test @MainActor
func changingContextAppliesToNextLookupAndRetry() async {
    let suite = "ProfessionalContextTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let catalog = ProfessionalContextCatalog(defaults: defaults)
    let provider = ContextEchoProvider()
    let lookup = LookupCoordinator(explainer: provider, preferences: defaults, contextCatalog: catalog)
    lookup.selectedLanguage = .simpleEnglish
    lookup.text = "actor"

    await lookup.submit()
    #expect(provider.requests.last?.context == .general)
    #expect(lookup.result?.example == "General example for actor")

    #expect(catalog.select(id: ProfessionalContext.swiftIOS.id))
    await lookup.submit()
    #expect(provider.requests.last?.text == "actor")
    #expect(provider.requests.last?.context == .swiftIOS)
    #expect(lookup.result?.example == "Swift/iOS example for actor")

    #expect(catalog.addCustom(name: "Law", description: "Legal terminology"))
    await lookup.submit()
    #expect(provider.requests.last?.context.description == "Legal terminology")
    #expect(lookup.result?.example == "Law example for actor")
}

@MainActor
private final class ContextEchoProvider: LocalExplaining {
    var requests: [LookupRequest] = []

    func explain(_ request: LookupRequest) async throws -> LookupResult {
        requests.append(request)
        return LookupResult(
            meaning: "Meaning for \(request.text)",
            example: "\(request.context.name) example for \(request.text)",
            detail: ""
        )
    }
}
