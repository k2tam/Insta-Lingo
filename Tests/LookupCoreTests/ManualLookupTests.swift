import Foundation
import Testing
@testable import LookupCore

@Test @MainActor
func manualLookupShowsLoadingThenExplanation() async {
    let provider = ControllableProvider()
    let lookup = LookupCoordinator(explainer: provider, preferences: testPreferences())
    lookup.selectedLanguage = .simpleEnglish
    lookup.text = "  concurrency  "

    let task = Task { await lookup.submit() }
    await provider.waitUntilRequested()
    #expect(lookup.phase == .loading)
    #expect(provider.requests.map(\.text) == ["concurrency"])

    provider.complete(.success(.init(
        meaning: "Things happening at the same time.",
        example: "Two tasks run concurrently.",
        detail: "The tasks may overlap."
    )))
    await task.value

    #expect(lookup.phase == .result)
    #expect(lookup.result?.meaning == "Things happening at the same time.")
    #expect(lookup.result?.example == "Two tasks run concurrently.")
    #expect(lookup.result?.detail == "The tasks may overlap.")
}

@Test @MainActor
func manualLookupShowsProviderErrorWithoutFakeResult() async {
    let provider = ControllableProvider()
    let lookup = LookupCoordinator(explainer: provider, preferences: testPreferences())
    lookup.selectedLanguage = .simpleEnglish
    lookup.text = "apple"

    let task = Task { await lookup.submit() }
    await provider.waitUntilRequested()
    provider.complete(.failure(TestError.unavailable))
    await task.value

    #expect(lookup.phase == .error("The on-device model is unavailable."))
    #expect(lookup.result == nil)
}

@Test @MainActor
func emptyManualLookupDoesNotContactModel() async {
    let provider = ControllableProvider()
    let lookup = LookupCoordinator(explainer: provider, preferences: testPreferences())
    lookup.text = " \n "

    await lookup.submit()

    #expect(lookup.phase == .error("Enter an English word or short phrase to look up."))
    #expect(provider.requests.isEmpty)
}

@Test @MainActor
func quickMeaningUsesVietnameseWithoutReplacingCompletedLookup() async throws {
    let explainer = RecordingExplainer()
    let translator = RecordingTranslator()
    let lookup = LookupCoordinator(
        explainer: explainer,
        translator: translator,
        preferences: testPreferences()
    )
    lookup.selectedSource = .local
    lookup.selectedLanguage = .simpleEnglish
    lookup.text = "scalable"
    await lookup.submit()

    let primary = lookup.completedLookup
    let result = try await lookup.quickMeaning(for: " demand ")

    #expect(translator.requests.map(\.request.text) == ["demand"])
    #expect(translator.requests.map(\.target) == [.vietnamese])
    #expect(result.meaning == "nhu cầu")
    #expect(lookup.completedLookup == primary)
    #expect(lookup.text == "scalable")
    #expect(lookup.phase == .result)
}

@MainActor
private final class RecordingExplainer: LocalExplaining {
    func explain(_ request: LookupRequest) async throws -> LookupResult {
        LookupResult(meaning: "Able to grow.", example: "A scalable service grows.", detail: "")
    }
}

@MainActor
private final class RecordingTranslator: LocalTranslating {
    struct Request {
        let request: LookupRequest
        let target: TargetLanguage
    }

    var requests: [Request] = []

    func supportedTargetLanguages() async -> [TargetLanguage] { [.vietnamese] }

    func translate(_ request: LookupRequest, to target: TargetLanguage) async throws -> LookupResult {
        requests.append(Request(request: request, target: target))
        return LookupResult(meaning: "nhu cầu", example: "Demand increased.", detail: "")
    }
}

@MainActor
private final class ControllableProvider: LocalExplaining {
    var requests: [LookupRequest] = []
    private var continuation: CheckedContinuation<LookupResult, Error>?
    private var requestSignal: CheckedContinuation<Void, Never>?
    private var didRequest = false

    func explain(_ request: LookupRequest) async throws -> LookupResult {
        requests.append(request)
        didRequest = true
        requestSignal?.resume()
        requestSignal = nil
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func waitUntilRequested() async {
        if didRequest { return }
        await withCheckedContinuation { requestSignal = $0 }
    }

    func complete(_ result: Result<LookupResult, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}

private enum TestError: LocalizedError {
    case unavailable

    var errorDescription: String? { "The on-device model is unavailable." }
}

private func testPreferences() -> UserDefaults {
    let suite = "InstaLingo.Tests.\(UUID().uuidString)"
    return UserDefaults(suiteName: suite)!
}
