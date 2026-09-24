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
private final class SelectionRecordingExplainer: LocalExplaining {
    var requests: [LookupRequest] = []
    func explain(_ request: LookupRequest) async throws -> LookupResult {
        requests.append(request)
        return LookupResult(meaning: "Meaning", example: "Example", detail: "")
    }
}
