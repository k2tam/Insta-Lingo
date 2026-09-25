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
func customContextsCanBeEditedAndRemovedAcrossLaunches() {
    let suite = "ProfessionalContextTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let catalog = ProfessionalContextCatalog(defaults: defaults)
    #expect(catalog.addCustom(name: "Finance", description: "Money terms"))
    let id = catalog.selectedContext.id
    #expect(!catalog.updateCustom(id: id, name: "General", description: "Duplicate"))
    #expect(!catalog.updateCustom(id: ProfessionalContext.swiftIOS.id, name: "Changed", description: "Built-in"))
    #expect(catalog.updateCustom(id: id, name: " Accounting ", description: " Financial reporting "))
    #expect(catalog.selectedContext.name == "Accounting")
    #expect(catalog.selectedContext.description == "Financial reporting")
    #expect(ProfessionalContextCatalog(defaults: defaults).selectedContext == catalog.selectedContext)

    #expect(!catalog.removeCustom(id: ProfessionalContext.swiftIOS.id))
    #expect(catalog.removeCustom(id: id))
    #expect(catalog.selectedContext == .general)
    #expect(ProfessionalContextCatalog(defaults: defaults).contexts == ProfessionalContext.builtIns)
    #expect(ProfessionalContextCatalog(defaults: defaults).selectedContext == .general)
}

@Test @MainActor
func contextsCanBeManagedAndVisibilityPersistsAcrossLaunches() {
    let suite = "ProfessionalContextTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let catalog = ProfessionalContextCatalog(defaults: defaults)
    #expect(catalog.update(id: ProfessionalContext.swiftIOS.id, name: "Apple apps", description: "Swift and iOS terms"))
    #expect(catalog.setVisible(false, id: ProfessionalContext.general.id))
    #expect(catalog.selectedContext.id == ProfessionalContext.softwareDevelopment.id)
    #expect(!catalog.select(id: ProfessionalContext.general.id))
    #expect(catalog.visibleContexts.map(\.id) == [ProfessionalContext.softwareDevelopment.id, ProfessionalContext.swiftIOS.id])

    let reopened = ProfessionalContextCatalog(defaults: defaults)
    #expect(reopened.contexts.last?.name == "Apple apps")
    #expect(reopened.visibleContexts.map(\.id) == catalog.visibleContexts.map(\.id))
    #expect(reopened.selectedContext.id == ProfessionalContext.softwareDevelopment.id)
    #expect(reopened.remove(id: ProfessionalContext.softwareDevelopment.id))
    #expect(reopened.selectedContext.id == ProfessionalContext.swiftIOS.id)
    #expect(reopened.setVisible(false, id: ProfessionalContext.general.id) == false)
    #expect(reopened.setVisible(false, id: ProfessionalContext.swiftIOS.id) == false)
    #expect(reopened.remove(id: ProfessionalContext.swiftIOS.id))
    #expect(reopened.selectedContext.id == ProfessionalContext.general.id)
    #expect(!reopened.remove(id: ProfessionalContext.general.id))
    #expect(ProfessionalContextCatalog(defaults: defaults).contexts == [.general])
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

@Test @MainActor
func changingContextRefreshesTheCurrentLookup() async {
    let suite = "ProfessionalContextTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let catalog = ProfessionalContextCatalog(defaults: defaults)
    let provider = ContextEchoProvider()
    let lookup = LookupCoordinator(explainer: provider, preferences: defaults, contextCatalog: catalog)
    lookup.selectedLanguage = .simpleEnglish
    lookup.text = "actor"

    await lookup.submit()
    #expect(catalog.select(id: ProfessionalContext.swiftIOS.id))
    await lookup.refreshForSelectedContext()

    #expect(provider.requests == [
        LookupRequest(text: "actor", context: .general),
        LookupRequest(text: "actor", context: .swiftIOS)
    ])
    #expect(lookup.result?.example == "Swift/iOS example for actor")
}

@Test @MainActor
func changingContextDuringLoadingKeepsOnlyTheNewContextResult() async {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let catalog = ProfessionalContextCatalog(defaults: defaults)
    let provider = PendingContextProvider()
    let lookup = LookupCoordinator(explainer: provider, preferences: defaults, contextCatalog: catalog)
    lookup.selectedLanguage = .simpleEnglish
    lookup.text = "actor"

    let first = Task { await lookup.submit() }
    await provider.waitForRequestCount(1)
    #expect(catalog.select(id: ProfessionalContext.swiftIOS.id))
    let refreshed = Task { await lookup.refreshForSelectedContext() }
    await provider.waitForRequestCount(2)

    provider.completeRequest(at: 1, meaning: "Swift actor")
    await refreshed.value
    provider.completeRequest(at: 0, meaning: "General actor")
    await first.value

    #expect(provider.requests.map(\.context) == [.general, .swiftIOS])
    #expect(lookup.result?.meaning == "Swift actor")
    #expect(lookup.completedLookup?.request.context == .swiftIOS)
}

@MainActor
private final class PendingContextProvider: LocalExplaining {
    var requests: [LookupRequest] = []
    private var completions: [CheckedContinuation<LookupResult, Error>] = []
    private var requestWaiter: CheckedContinuation<Void, Never>?
    private var awaitedCount = 0

    func explain(_ request: LookupRequest) async throws -> LookupResult {
        requests.append(request)
        if requests.count >= awaitedCount {
            requestWaiter?.resume()
            requestWaiter = nil
        }
        return try await withCheckedThrowingContinuation { completions.append($0) }
    }

    func waitForRequestCount(_ count: Int) async {
        if requests.count >= count { return }
        awaitedCount = count
        await withCheckedContinuation { requestWaiter = $0 }
    }

    func completeRequest(at index: Int, meaning: String) {
        completions[index].resume(returning: LookupResult(meaning: meaning, example: "Example", detail: ""))
    }
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
