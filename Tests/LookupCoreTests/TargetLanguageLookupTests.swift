import Foundation
import Testing
@testable import LookupCore

@Test @MainActor
func defaultsToVietnameseAndRoutesToTranslator() async {
    let explainer = TestExplainer()
    let translator = TestTranslator()
    let lookup = LookupCoordinator(explainer: explainer, translator: translator, preferences: isolatedPreferences())
    #expect(lookup.selectedLanguage == .vietnamese)
    lookup.text = "  concurrency "

    await lookup.submit()

    #expect(translator.requests == [LookupRequest(text: "concurrency")])
    #expect(translator.targets == [.vietnamese])
    #expect(explainer.requests.isEmpty)
    #expect(lookup.result?.meaning == "sự đồng thời")
    #expect(lookup.phase == .result)
}

@Test @MainActor
func selectedLanguageSurvivesCoordinatorRecreation() async {
    let preferences = isolatedPreferences()
    let translator = TestTranslator()
    let first = LookupCoordinator(explainer: TestExplainer(), translator: translator, preferences: preferences)
    first.selectedLanguage = TargetLanguage(code: "ja")

    let reopened = LookupCoordinator(explainer: TestExplainer(), translator: translator, preferences: preferences)
    #expect(reopened.selectedLanguage == TargetLanguage(code: "ja"))
    reopened.text = "apple"
    await reopened.submit()
    #expect(translator.targets == [TargetLanguage(code: "ja")])
}

@Test @MainActor
func unsupportedLocalPairShowsErrorWithoutSwitchingProvider() async {
    let explainer = TestExplainer()
    let translator = TestTranslator()
    translator.error = TranslationFailure.unsupported
    let lookup = LookupCoordinator(explainer: explainer, translator: translator, preferences: isolatedPreferences())
    lookup.selectedLanguage = TargetLanguage(code: "xx")
    lookup.text = "apple"

    await lookup.submit()

    #expect(lookup.phase == .error("This language pair is unavailable on this Mac."))
    #expect(lookup.result == nil)
    #expect(explainer.requests.isEmpty)
}

@MainActor
private final class TestExplainer: LocalExplaining {
    var requests: [LookupRequest] = []

    func explain(_ request: LookupRequest) async throws -> LookupResult {
        requests.append(request)
        return LookupResult(meaning: "English meaning", example: "Example", detail: "")
    }
}

@MainActor
private final class TestTranslator: LocalTranslating {
    var requests: [LookupRequest] = []
    var targets: [TargetLanguage] = []
    var error: Error?

    func supportedTargetLanguages() async -> [TargetLanguage] { [.vietnamese] }

    func translate(_ request: LookupRequest, to target: TargetLanguage) async throws -> LookupResult {
        requests.append(request)
        targets.append(target)
        if let error { throw error }
        return LookupResult(meaning: "sự đồng thời", example: "", detail: "")
    }
}

private enum TranslationFailure: LocalizedError {
    case unsupported

    var errorDescription: String? { "This language pair is unavailable on this Mac." }
}

private func isolatedPreferences() -> UserDefaults {
    UserDefaults(suiteName: "TransAtGlance.TargetTests.\(UUID().uuidString)")!
}
