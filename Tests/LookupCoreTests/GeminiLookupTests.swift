import Foundation
import Testing
@testable import LookupCore

@Test @MainActor
func localLookupNeverCallsGeminiEvenWhenConfigured() async throws {
    let defaults = UserDefaults(suiteName: "GeminiLookupTests.\(UUID())")!
    let credentials = FakeGeminiCredentials()
    let config = GeminiConfiguration(defaults: defaults, credentials: credentials)
    try config.saveAPIKey("secret")
    config.setEnabled(true)
    let gemini = RecordingGemini()
    let local = RecordingLocal()
    let lookup = LookupCoordinator(explainer: local, gemini: gemini, geminiConfiguration: config, preferences: defaults)
    lookup.selectedLanguage = .simpleEnglish
    lookup.text = "actor"

    await lookup.submit()

    #expect(local.requests.map(\.text) == ["actor"])
    #expect(gemini.calls.isEmpty)
    #expect(lookup.selectedSource == .local)
}

@Test @MainActor
func geminiRequiresOptInAndKeyAndSendsOnlySelectedLookupInputs() async throws {
    let defaults = UserDefaults(suiteName: "GeminiLookupTests.\(UUID())")!
    let credentials = FakeGeminiCredentials()
    let config = GeminiConfiguration(defaults: defaults, credentials: credentials)
    let gemini = RecordingGemini()
    let local = RecordingLocal()
    let lookup = LookupCoordinator(explainer: local, gemini: gemini, geminiConfiguration: config, preferences: defaults)
    lookup.text = "  actor  "
    lookup.selectedLanguage = .vietnamese
    _ = lookup.contextCatalog.select(id: ProfessionalContext.swiftIOS.id)

    lookup.selectedSource = .gemini
    await lookup.submit()
    #expect(gemini.calls.isEmpty)
    #expect(lookup.phase == .error(GeminiConfigurationError.disabled.localizedDescription))

    config.setEnabled(true)
    lookup.selectedSource = .gemini
    await lookup.submit()
    #expect(gemini.calls.isEmpty)
    #expect(lookup.phase == .error(GeminiConfigurationError.missingKey.localizedDescription))

    try config.saveAPIKey("secret")
    lookup.selectedSource = .gemini
    await lookup.submit()
    #expect(gemini.calls.count == 1)
    #expect(gemini.calls.first?.request.text == "actor")
    #expect(gemini.calls.first?.request.context == .swiftIOS)
    #expect(gemini.calls.first?.target == .vietnamese)
    #expect(gemini.calls.first?.key == "secret")
    #expect(local.requests.isEmpty)
    #expect(lookup.phase == .result)
    #expect(lookup.selectedSource == .local)
}

@MainActor
private final class FakeGeminiCredentials: GeminiCredentialStoring {
    var key: String?
    func read() throws -> String? { key }
    func save(_ key: String) throws { self.key = key }
    func delete() throws { key = nil }
}

@MainActor
private final class RecordingGemini: GeminiLookupProviding {
    struct Call {
        let request: LookupRequest
        let target: TargetLanguage
        let key: String
    }
    var calls: [Call] = []
    func lookup(_ request: LookupRequest, to target: TargetLanguage, apiKey: String) async throws -> LookupResult {
        calls.append(Call(request: request, target: target, key: apiKey))
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
