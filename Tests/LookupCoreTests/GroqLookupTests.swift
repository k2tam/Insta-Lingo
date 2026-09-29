import Foundation
import Testing
@testable import LookupCore

@Test @MainActor
func localLookupNeverCallsGroqWhenExplicitlySelected() async throws {
    let defaults = UserDefaults(suiteName: "GroqLookupTests.\(UUID())")!
    let credentials = FakeGroqCredentials(key: "secret")
    let configuration = GroqConfiguration(credentials: credentials)
    let groq = RecordingGroq()
    let local = RecordingLocal()
    let lookup = LookupCoordinator(
        explainer: local,
        groq: groq,
        groqConfiguration: configuration,
        preferences: defaults
    )
    lookup.selectedLanguage = .simpleEnglish
    lookup.selectedSource = .local
    lookup.text = "actor"

    await lookup.submit()

    #expect(local.requests.map(\.text) == ["actor"])
    #expect(groq.calls.isEmpty)
    #expect(lookup.selectedSource == .local)
}

@Test @MainActor
func groqIsDefaultAndReceivesOnlySelectedLookupInputs() async throws {
    let defaults = UserDefaults(suiteName: "GroqLookupTests.\(UUID())")!
    let credentials = FakeGroqCredentials(key: "secret")
    let configuration = GroqConfiguration(credentials: credentials)
    let groq = RecordingGroq()
    let local = RecordingLocal()
    let lookup = LookupCoordinator(
        explainer: local,
        groq: groq,
        groqConfiguration: configuration,
        preferences: defaults
    )
    lookup.text = "  actor  "
    lookup.selectedLanguage = .vietnamese
    _ = lookup.contextCatalog.select(id: ProfessionalContext.swiftIOS.id)

    await lookup.submit()

    #expect(groq.calls.count == 1)
    #expect(groq.calls.first?.request.text == "actor")
    #expect(groq.calls.first?.request.context == .swiftIOS)
    #expect(groq.calls.first?.target == .vietnamese)
    #expect(groq.calls.first?.apiKey == "secret")
    #expect(local.requests.isEmpty)
    #expect(lookup.phase == .result)
    #expect(lookup.selectedSource == .groq)
}

@Test @MainActor
func groqRequiresAPIKeyBeforeSendingLookup() async {
    let credentials = FakeGroqCredentials()
    let configuration = GroqConfiguration(credentials: credentials)
    let groq = RecordingGroq()
    let lookup = LookupCoordinator(
        explainer: RecordingLocal(),
        groq: groq,
        groqConfiguration: configuration,
        preferences: UserDefaults(suiteName: "GroqLookupTests.\(UUID())")!
    )
    lookup.text = "actor"

    await lookup.submit()

    #expect(groq.calls.isEmpty)
    #expect(lookup.phase == .error(GroqConfigurationError.missingKey.localizedDescription))
}

@Test @MainActor
func groqConfigurationTrimsAndRemovesKey() throws {
    let credentials = FakeGroqCredentials()
    let configuration = GroqConfiguration(credentials: credentials)

    try configuration.saveAPIKey("  secret  ")

    #expect(configuration.hasAPIKey)
    #expect(try configuration.keyForLookup() == "secret")
    try configuration.removeAPIKey()
    #expect(!configuration.hasAPIKey)
    #expect(credentials.key == nil)
}

@Test @MainActor
func groqModelAndEffortPersistAcrossConfigurationInstances() {
    let defaults = UserDefaults(suiteName: "GroqModelTests.\(UUID())")!
    let credentials = FakeGroqCredentials()
    let configuration = GroqConfiguration(credentials: credentials, preferences: defaults)

    #expect(configuration.model == .gptOSS120B)
    #expect(configuration.reasoningEffort == .low)

    configuration.model = .gptOSS20B
    configuration.reasoningEffort = .high

    let restored = GroqConfiguration(credentials: credentials, preferences: defaults)
    #expect(restored.model == .gptOSS20B)
    #expect(restored.reasoningEffort == .high)
    #expect(restored.model.supportedEfforts.contains(restored.reasoningEffort))
}

@Test @MainActor
func repeatedGroqLookupIsServedFromCacheUntilTargetOrContextChanges() async {
    let defaults = UserDefaults(suiteName: "GroqLookupTests.\(UUID())")!
    let configuration = GroqConfiguration(credentials: FakeGroqCredentials(key: "secret"), preferences: defaults)
    let groq = RecordingGroq()
    let lookup = LookupCoordinator(
        explainer: RecordingLocal(), groq: groq, groqConfiguration: configuration, preferences: defaults
    )
    lookup.selectedLanguage = .simpleEnglish
    lookup.text = "Actor"
    await lookup.submit()
    lookup.text = "actor"
    await lookup.submit()

    #expect(groq.calls.count == 1)
    #expect(lookup.phase == .result)
    #expect(lookup.completedLookup?.result.meaning == "diễn viên")

    lookup.selectedLanguage = .vietnamese
    await lookup.submit()
    #expect(groq.calls.count == 2)

    let other = lookup.contextCatalog.contexts.first { $0.id != lookup.contextCatalog.selectedContext.id }!
    _ = lookup.contextCatalog.select(id: other.id)
    await lookup.submit()
    #expect(groq.calls.count == 3)
}

@Test @MainActor
func quickMeaningUsesQuickDepthAndIsCachedSeparately() async throws {
    let defaults = UserDefaults(suiteName: "GroqLookupTests.\(UUID())")!
    let configuration = GroqConfiguration(credentials: FakeGroqCredentials(key: "secret"), preferences: defaults)
    let groq = RecordingGroq()
    let lookup = LookupCoordinator(
        explainer: RecordingLocal(), groq: groq, groqConfiguration: configuration, preferences: defaults
    )
    lookup.selectedLanguage = .vietnamese
    lookup.text = "actor"
    await lookup.submit()
    _ = try await lookup.quickMeaning(for: "actor")
    _ = try await lookup.quickMeaning(for: "actor")

    #expect(groq.calls.map(\.depth) == [.full, .quick])
}

@MainActor
private final class FakeGroqCredentials: GroqCredentialStoring {
    var key: String?

    init(key: String? = nil) {
        self.key = key
    }

    func read() throws -> String? { key }
    func save(_ key: String) throws { self.key = key }
    func delete() throws { key = nil }
}

@MainActor
private final class RecordingGroq: GroqLookupProviding {
    struct Call {
        let request: LookupRequest
        let target: TargetLanguage
        let apiKey: String
        let depth: LookupDepth
    }

    var calls: [Call] = []

    func lookup(_ request: LookupRequest, to target: TargetLanguage, apiKey: String, depth: LookupDepth) async throws -> LookupResult {
        calls.append(Call(request: request, target: target, apiKey: apiKey, depth: depth))
        return LookupResult(meaning: "diễn viên", example: "An actor runs on the main thread.", detail: "")
    }
}

@MainActor
private final class RecordingLocal: LocalExplaining {
    var requests: [LookupRequest] = []

    func explain(_ request: LookupRequest) async throws -> LookupResult {
        requests.append(request)
        return LookupResult(meaning: "local", example: "example", detail: "")
    }
}
