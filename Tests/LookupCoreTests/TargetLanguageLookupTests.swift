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
func onlyVietnameseAndEnglishAreOfferedAndLegacySelectionFallsBack() async {
    let preferences = isolatedPreferences()
    let translator = TestTranslator()
    preferences.set("ja", forKey: "lookup.targetLanguage")
    let reopened = LookupCoordinator(explainer: TestExplainer(), translator: translator, preferences: preferences)
    await reopened.loadAvailableLanguages()
    #expect(reopened.selectedLanguage == .vietnamese)
    #expect(reopened.availableLanguages == [.vietnamese, .simpleEnglish])
    reopened.selectedLanguage = .simpleEnglish
    #expect(LookupCoordinator(explainer: TestExplainer(), translator: translator, preferences: preferences).selectedLanguage == .simpleEnglish)
}

@Test @MainActor
func englishResultCanLoadVietnameseCompanionOnDemand() async {
    let explainer = TestExplainer()
    let translator = TestTranslator()
    let lookup = LookupCoordinator(explainer: explainer, translator: translator, preferences: isolatedPreferences())
    lookup.selectedLanguage = .simpleEnglish
    lookup.text = "apple"
    await lookup.submit()
    #expect(translator.requests.isEmpty)
    await lookup.loadVietnameseResult()
    #expect(translator.requests == [LookupRequest(text: "apple")])
    #expect(translator.targets == [.vietnamese])
    #expect(lookup.vietnameseResult?.meaning == "sự đồng thời")
    #expect(lookup.result?.meaning == "English meaning")
    await lookup.loadVietnameseResult()
    #expect(translator.requests.count == 1)
    lookup.text = "banana"
    #expect(lookup.vietnameseResult == nil)
    #expect(lookup.vietnamesePhase == .idle)
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

    func supportedTargetLanguages() async -> [TargetLanguage] { [.vietnamese, TargetLanguage(code: "ja")] }

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
