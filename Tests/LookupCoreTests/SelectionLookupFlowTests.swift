import Foundation
import Testing
@testable import LookupCore

@Test @MainActor
func selectedTextIsTheOnlyTextSubmitted() async {
    let explainer = SelectionRecordingExplainer()
    let lookup = LookupCoordinator(explainer: explainer, preferences: UserDefaults(suiteName: UUID().uuidString)!)
    lookup.selectedLanguage = .simpleEnglish
    lookup.text = "previous manual entry"
    let flow = SelectionLookupFlow(reader: StubSelectedTextReader(result: .selected("  actor isolation  ")))

    await flow.start(lookup: lookup)

    #expect(explainer.requests.map(\.text) == ["actor isolation"])
    #expect(lookup.text == "actor isolation")
    #expect(lookup.phase == .result)
    #expect(flow.status == .idle)
}

@Test @MainActor
func permissionIsRequestedOnActionAndCanBeRetried() async {
    let reader = SequencedSelectedTextReader(results: [.permissionRequired, .selected("Swift actor")])
    let explainer = SelectionRecordingExplainer()
    let lookup = LookupCoordinator(explainer: explainer, preferences: UserDefaults(suiteName: UUID().uuidString)!)
    lookup.selectedLanguage = .simpleEnglish
    let flow = SelectionLookupFlow(reader: reader)
    #expect(reader.calls == 0)

    await flow.start(lookup: lookup)
    #expect(flow.status == .permissionRequired)
    #expect(explainer.requests.isEmpty)

    await flow.start(lookup: lookup)
    #expect(reader.calls == 2)
    #expect(explainer.requests.map(\.text) == ["Swift actor"])
    #expect(flow.status == .idle)
}

@Test @MainActor
func transientlyUnavailableBrowserSelectionIsRetried() async {
    let reader = SequencedSelectedTextReader(results: [.unavailable, .selected("browser")])
    let explainer = SelectionRecordingExplainer()
    let lookup = LookupCoordinator(explainer: explainer, preferences: UserDefaults(suiteName: UUID().uuidString)!)
    lookup.selectedLanguage = .simpleEnglish
    let flow = SelectionLookupFlow(reader: reader)

    await flow.start(lookup: lookup)

    #expect(reader.calls == 2)
    #expect(explainer.requests.map(\.text) == ["browser"])
    #expect(flow.status == .idle)
}

@Test @MainActor
func slowAccessibilityTreeIsRetriedUntilTheLastAttempt() async {
    let reader = SequencedSelectedTextReader(results: [.unavailable, .unavailable, .unavailable, .unavailable, .selected("chat")])
    let explainer = SelectionRecordingExplainer()
    let lookup = LookupCoordinator(explainer: explainer, preferences: UserDefaults(suiteName: UUID().uuidString)!)
    lookup.selectedLanguage = .simpleEnglish
    let flow = SelectionLookupFlow(reader: reader)

    await flow.start(lookup: lookup)

    #expect(reader.calls == 5)
    #expect(explainer.requests.map(\.text) == ["chat"])
}

@Test @MainActor
func fallbackReaderIsTriedOnceAfterAccessibilityGivesUp() async {
    let reader = StubSelectedTextReader(result: .unavailable)
    let fallback = SequencedSelectedTextReader(results: [.selected("copied")])
    let explainer = SelectionRecordingExplainer()
    let lookup = LookupCoordinator(explainer: explainer, preferences: UserDefaults(suiteName: UUID().uuidString)!)
    lookup.selectedLanguage = .simpleEnglish
    let flow = SelectionLookupFlow(reader: reader, fallbackReader: fallback)

    await flow.start(lookup: lookup)

    #expect(fallback.calls == 1)
    #expect(explainer.requests.map(\.text) == ["copied"])
}

@Test @MainActor
func fallbackReaderIsSkippedWhenPermissionIsRequired() async {
    let fallback = SequencedSelectedTextReader(results: [])
    let lookup = LookupCoordinator(explainer: SelectionRecordingExplainer(), preferences: UserDefaults(suiteName: UUID().uuidString)!)
    let flow = SelectionLookupFlow(reader: StubSelectedTextReader(result: .permissionRequired), fallbackReader: fallback)

    await flow.start(lookup: lookup)

    #expect(fallback.calls == 0)
    #expect(flow.status == .permissionRequired)
}

@Test @MainActor
func appWhereOnlyFallbackWorksStartsWithFallbackNextTime() async {
    let preferences = UserDefaults(suiteName: UUID().uuidString)!
    let reader = CountingSelectedTextReader(result: .unavailable)
    let fallback = CountingSelectedTextReader(result: .selected("chat"))
    let lookup = LookupCoordinator(explainer: SelectionRecordingExplainer(), preferences: preferences)
    lookup.selectedLanguage = .simpleEnglish
    let flow = SelectionLookupFlow(reader: reader, fallbackReader: fallback, sourceAppID: { "net.whatsapp.WhatsApp" }, preferences: preferences)

    await flow.start(lookup: lookup)
    #expect(reader.calls == 5)
    #expect(fallback.calls == 1)

    await flow.start(lookup: lookup)
    #expect(reader.calls == 5)
    #expect(fallback.calls == 2)
}

@Test @MainActor
func rememberedAppIsKeptWhenNothingIsSelectedAndForgottenWhenPrimaryWorks() async {
    let preferences = UserDefaults(suiteName: UUID().uuidString)!
    preferences.set(["net.whatsapp.WhatsApp"], forKey: SelectionLookupFlow.fallbackFirstAppsKey)
    let reader = CountingSelectedTextReader(result: .unavailable)
    let fallback = CountingSelectedTextReader(result: .unavailable)
    let lookup = LookupCoordinator(explainer: SelectionRecordingExplainer(), preferences: preferences)
    lookup.selectedLanguage = .simpleEnglish
    let flow = SelectionLookupFlow(reader: reader, fallbackReader: fallback, sourceAppID: { "net.whatsapp.WhatsApp" }, preferences: preferences)

    await flow.start(lookup: lookup)
    #expect(flow.status == .regionFallback)
    #expect(preferences.stringArray(forKey: SelectionLookupFlow.fallbackFirstAppsKey) == ["net.whatsapp.WhatsApp"])

    flow.reset()
    reader.result = .selected("chat")
    await flow.start(lookup: lookup)
    #expect(preferences.stringArray(forKey: SelectionLookupFlow.fallbackFirstAppsKey) == [])
}

@Test @MainActor
func appsWhereAccessibilityWorksNeverUseFallback() async {
    let preferences = UserDefaults(suiteName: UUID().uuidString)!
    let fallback = CountingSelectedTextReader(result: .selected("copied"))
    let lookup = LookupCoordinator(explainer: SelectionRecordingExplainer(), preferences: preferences)
    lookup.selectedLanguage = .simpleEnglish
    let flow = SelectionLookupFlow(
        reader: StubSelectedTextReader(result: .selected("safari")),
        fallbackReader: fallback,
        sourceAppID: { "com.apple.Safari" },
        preferences: preferences
    )

    await flow.start(lookup: lookup)

    #expect(fallback.calls == 0)
    #expect(preferences.stringArray(forKey: SelectionLookupFlow.fallbackFirstAppsKey) == nil)
}

@Test(arguments: [SelectionReadResult.unavailable, .selected("   ")]) @MainActor
func unreadableOrEmptySelectionOffersRegionFallback(result: SelectionReadResult) async {
    let explainer = SelectionRecordingExplainer()
    let lookup = LookupCoordinator(explainer: explainer, preferences: UserDefaults(suiteName: UUID().uuidString)!)
    lookup.text = "previous manual entry"
    let flow = SelectionLookupFlow(reader: StubSelectedTextReader(result: result))

    await flow.start(lookup: lookup)

    #expect(flow.status == .regionFallback)
    #expect(explainer.requests.isEmpty)
    #expect(lookup.text == "previous manual entry")
}

@MainActor
private struct StubSelectedTextReader: SelectedTextReading {
    let result: SelectionReadResult
    func readSelectedText() async -> SelectionReadResult { result }
}

@MainActor
private final class SequencedSelectedTextReader: SelectedTextReading {
    var results: [SelectionReadResult]
    var calls = 0
    init(results: [SelectionReadResult]) { self.results = results }
    func readSelectedText() async -> SelectionReadResult {
        calls += 1
        return results.removeFirst()
    }
}

@MainActor
private final class CountingSelectedTextReader: SelectedTextReading {
    var result: SelectionReadResult
    var calls = 0
    init(result: SelectionReadResult) { self.result = result }
    func readSelectedText() async -> SelectionReadResult {
        calls += 1
        return result
    }
}

@MainActor
private final class SelectionRecordingExplainer: LocalExplaining {
    var requests: [LookupRequest] = []
    func explain(_ request: LookupRequest) async throws -> LookupResult {
        requests.append(request)
        return LookupResult(meaning: "Meaning", example: "Example", detail: "")
    }
}
