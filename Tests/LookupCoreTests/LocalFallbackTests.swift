import Foundation
import Testing
@testable import LookupCore

@Test @MainActor
func unavailableLocalLookupAsksThenRemembersGeminiConsent() async throws {
    let defaults = UserDefaults(suiteName: "LocalFallbackTests.\(UUID())")!
    let credentials = FallbackCredentials(key: "secret")
    let configuration = GeminiConfiguration(defaults: defaults, credentials: credentials)
    configuration.setEnabled(true)
    let fallback = GeminiFallbackSettings(defaults: defaults)
    let gemini = FallbackGemini()
    let lookup = LookupCoordinator(
        explainer: UnavailableExplainer(), gemini: gemini,
        geminiConfiguration: configuration, fallbackSettings: fallback,
        preferences: defaults
    )
    lookup.selectedLanguage = .simpleEnglish
    lookup.text = "actor"

    await lookup.submit()
    #expect(lookup.phase == .fallbackPrompt("Apple Intelligence is unavailable."))
    #expect(gemini.requests.isEmpty)

    await lookup.resolveFallback(.allow)
    #expect(fallback.choice == .allow)
    #expect(lookup.phase == .result)
    #expect(gemini.requests.map(\.text) == ["actor"])

    let next = LookupCoordinator(
        explainer: UnavailableExplainer(), gemini: gemini,
        geminiConfiguration: configuration,
        fallbackSettings: GeminiFallbackSettings(defaults: defaults), preferences: defaults
    )
    next.selectedLanguage = .simpleEnglish
    next.text = "delegate"
    await next.submit()
    #expect(next.phase == .result)
    #expect(gemini.requests.map(\.text) == ["actor", "delegate"])
}

@Test @MainActor
func decliningFallbackIsRememberedAndSendsNothing() async {
    let defaults = UserDefaults(suiteName: "LocalFallbackTests.\(UUID())")!
    let configuration = GeminiConfiguration(defaults: defaults, credentials: FallbackCredentials(key: "secret"))
    configuration.setEnabled(true)
    let fallback = GeminiFallbackSettings(defaults: defaults)
    let gemini = FallbackGemini()
    let lookup = LookupCoordinator(
        explainer: UnavailableExplainer(), gemini: gemini,
        geminiConfiguration: configuration, fallbackSettings: fallback,
        preferences: defaults
    )
    lookup.selectedLanguage = .simpleEnglish
    lookup.text = "actor"

    await lookup.submit()
    await lookup.resolveFallback(.decline)
    #expect(fallback.choice == .decline)
    #expect(lookup.phase == .error("Apple Intelligence is unavailable."))
    #expect(gemini.requests.isEmpty)

    await lookup.submit()
    #expect(lookup.phase == .error("Apple Intelligence is unavailable."))
    #expect(gemini.requests.isEmpty)

    fallback.choice = .ask
    await lookup.submit()
    #expect(lookup.phase == .fallbackPrompt("Apple Intelligence is unavailable."))
}

@Test @MainActor
func disabledOrUnconfiguredGeminiNeverPromptsOrReceivesLocalText() async throws {
    let defaults = UserDefaults(suiteName: "LocalFallbackTests.\(UUID())")!
    let credentials = FallbackCredentials()
    let configuration = GeminiConfiguration(defaults: defaults, credentials: credentials)
    let fallback = GeminiFallbackSettings(defaults: defaults)
    let gemini = FallbackGemini()
    let lookup = LookupCoordinator(
        explainer: UnavailableExplainer(), gemini: gemini,
        geminiConfiguration: configuration, fallbackSettings: fallback,
        preferences: defaults
    )
    lookup.selectedLanguage = .simpleEnglish
    lookup.text = "actor"

    await lookup.submit()
    #expect(lookup.phase == .error("Apple Intelligence is unavailable."))

    configuration.setEnabled(true)
    await lookup.submit()
    #expect(lookup.phase == .error("Apple Intelligence is unavailable."))

    try configuration.saveAPIKey("secret")
    await lookup.submit()
    #expect(lookup.phase == .fallbackPrompt("Apple Intelligence is unavailable."))
    #expect(gemini.requests.isEmpty)
}

@Test @MainActor
func localProcessingErrorDoesNotOfferCloudFallback() async throws {
    let defaults = UserDefaults(suiteName: "LocalFallbackTests.\(UUID())")!
    let configuration = GeminiConfiguration(defaults: defaults, credentials: FallbackCredentials(key: "secret"))
    configuration.setEnabled(true)
    let gemini = FallbackGemini()
    let lookup = LookupCoordinator(
        explainer: FailingExplainer(), gemini: gemini,
        geminiConfiguration: configuration,
        fallbackSettings: GeminiFallbackSettings(defaults: defaults), preferences: defaults
    )
    lookup.selectedLanguage = .simpleEnglish
    lookup.text = "actor"

    await lookup.submit()
    #expect(lookup.phase == .error("The Local result could not be generated."))
    #expect(gemini.requests.isEmpty)
}

@MainActor
private struct UnavailableExplainer: LocalExplaining {
    func explain(_ request: LookupRequest) async throws -> LookupResult {
        throw UnavailableError()
    }
}

private struct UnavailableError: LocalizedError, LocalLookupUnavailable {
    var errorDescription: String? { "Apple Intelligence is unavailable." }
}

@MainActor
private struct FailingExplainer: LocalExplaining {
    func explain(_ request: LookupRequest) async throws -> LookupResult {
        throw LocalProcessingError()
    }
}

private struct LocalProcessingError: LocalizedError {
    var errorDescription: String? { "The Local result could not be generated." }
}

@MainActor
private final class FallbackGemini: GeminiLookupProviding {
    var requests: [LookupRequest] = []
    func lookup(_ request: LookupRequest, to target: TargetLanguage, apiKey: String) async throws -> LookupResult {
        requests.append(request)
        return LookupResult(meaning: "cloud", example: "example", detail: "")
    }
}

@MainActor
private final class FallbackCredentials: GeminiCredentialStoring {
    var key: String?
    init(key: String? = nil) { self.key = key }
    func read() throws -> String? { key }
    func save(_ key: String) throws { self.key = key }
    func delete() throws { key = nil }
}
