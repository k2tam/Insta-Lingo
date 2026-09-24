import Foundation
import Testing
@testable import LookupCore

@Test @MainActor
func selectedRegionIsReviewedAndOnlyChosenPhraseIsLookedUp() async {
    let recognizer = FakeRegionRecognizer(result: OCRRecognition(text: "Swift actor isolation\nother words", confidence: 0.98))
    let explainer = RecordingExplainer()
    let lookup = LookupCoordinator(explainer: explainer, preferences: UserDefaults(suiteName: UUID().uuidString)!)
    lookup.selectedLanguage = .simpleEnglish
    let flow = OCRLookupFlow(recognizer: recognizer)
    var events: [String] = []

    await flow.start(lookup: lookup, hidePanel: { events.append("hide") }, showPanel: { events.append("show") })

    #expect(events == ["hide", "show"])
    #expect(flow.isReviewing)
    #expect(flow.recognizedText == "Swift actor isolation\nother words")
    #expect(explainer.requests.isEmpty)

    await flow.confirm(lookup: lookup, selectedText: " actor isolation ")

    #expect(explainer.requests.map(\.text) == ["actor isolation"])
    #expect(lookup.phase == .result)
    #expect(!flow.isReviewing)
}

@Test @MainActor
func cancelledRegionRestoresPanelWithoutLookup() async {
    let recognizer = FakeRegionRecognizer(result: nil)
    let flow = OCRLookupFlow(recognizer: recognizer)
    let lookup = LookupCoordinator(explainer: RecordingExplainer(), preferences: UserDefaults(suiteName: UUID().uuidString)!)
    var showCount = 0

    await flow.start(lookup: lookup, hidePanel: {}, showPanel: { showCount += 1 })

    #expect(showCount == 1)
    #expect(!flow.isReviewing)
    #expect(flow.errorMessage == nil)
}

@MainActor
private struct FakeRegionRecognizer: RegionTextRecognizing {
    let result: OCRRecognition?
    func recognizeSelectedRegion() async throws -> OCRRecognition? { result }
}

@Test @MainActor
func confidentShortOCRAutomaticallyLooksUpExactlyOnce() async {
    let explainer = RecordingExplainer()
    let lookup = LookupCoordinator(explainer: explainer, preferences: UserDefaults(suiteName: UUID().uuidString)!)
    lookup.selectedLanguage = .simpleEnglish
    let flow = OCRLookupFlow(recognizer: FakeRegionRecognizer(result: OCRRecognition(text: " actor isolation ", confidence: 0.96)))
    var events: [String] = []

    await flow.start(lookup: lookup, hidePanel: { events.append("hide") }, showPanel: { events.append("show") })

    #expect(events == ["hide", "show"])
    #expect(explainer.requests.map(\.text) == ["actor isolation"])
    #expect(lookup.phase == .result)
    #expect(!flow.isReviewing)
    await flow.confirm(lookup: lookup)
    #expect(explainer.requests.count == 1)
}

@Test(arguments: [
    OCRRecognition(text: "actor isolation", confidence: 0.70),
    OCRRecognition(text: "Swift actor isolation and asynchronous execution", confidence: 0.99),
    OCRRecognition(text: "Swift actor\nisolation", confidence: 0.99),
    OCRRecognition(text: "actor isolation?", confidence: 0.99),
]) @MainActor
func uncertainOrLongOCRWaitsForReview(result: OCRRecognition) async {
    let explainer = RecordingExplainer()
    let lookup = LookupCoordinator(explainer: explainer, preferences: UserDefaults(suiteName: UUID().uuidString)!)
    let flow = OCRLookupFlow(recognizer: FakeRegionRecognizer(result: result))

    await flow.start(lookup: lookup, hidePanel: {}, showPanel: {})

    #expect(flow.isReviewing)
    #expect(explainer.requests.isEmpty)
}

@MainActor
private final class RecordingExplainer: LocalExplaining {
    var requests: [LookupRequest] = []
    func explain(_ request: LookupRequest) async throws -> LookupResult {
        requests.append(request)
        return LookupResult(meaning: "Meaning", example: "Example", detail: "")
    }
}
