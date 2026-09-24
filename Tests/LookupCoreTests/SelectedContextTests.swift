import Foundation
import Testing
@testable import LookupCore

@Test @MainActor
func accessibilityReviewSendsOnlyChosenPhraseAndSentence() async {
    let source = "A Swift actor protects mutable state. Unselected material is unavailable."
    let explainer = ContextRecordingExplainer()
    let lookup = LookupCoordinator(explainer: explainer, preferences: UserDefaults(suiteName: UUID().uuidString)!)
    lookup.selectedLanguage = .simpleEnglish
    let flow = SelectionLookupFlow(reader: ContextTextReader(text: source))

    await flow.start(lookup: lookup, reviewSelection: true)
    #expect(flow.status == .reviewing)
    #expect(explainer.requests.isEmpty)

    await flow.confirm(lookup: lookup, phrase: "actor", sentence: "A Swift actor protects mutable state.")
    #expect(explainer.requests == [LookupRequest(text: "actor", selectedSentence: "A Swift actor protects mutable state.")])
}

@Test @MainActor
func accessibilityReviewRejectsContextOutsideTheSelectedText() async {
    let explainer = ContextRecordingExplainer()
    let lookup = LookupCoordinator(explainer: explainer, preferences: UserDefaults(suiteName: UUID().uuidString)!)
    let flow = SelectionLookupFlow(reader: ContextTextReader(text: "An actor protects state."))
    await flow.start(lookup: lookup, reviewSelection: true)

    await flow.confirm(lookup: lookup, phrase: "actor", sentence: "The actor owns all state.")
    #expect(flow.status == .reviewing)
    #expect(flow.errorMessage != nil)
    #expect(explainer.requests.isEmpty)
}

@Test @MainActor
func ocrReviewSendsOnlyChosenPhraseAndSentence() async {
    let explainer = ContextRecordingExplainer()
    let lookup = LookupCoordinator(explainer: explainer, preferences: UserDefaults(suiteName: UUID().uuidString)!)
    lookup.selectedLanguage = .simpleEnglish
    let source = "Swift actors protect mutable state.\nAnother line."
    let flow = OCRLookupFlow(recognizer: ContextRecognizer(text: source))
    await flow.start(lookup: lookup, hidePanel: {}, showPanel: {})
    #expect(flow.isReviewing)

    await flow.confirm(lookup: lookup, selectedText: "actors", selectedSentence: "Swift actors protect mutable state.")
    #expect(explainer.requests == [LookupRequest(text: "actors", selectedSentence: "Swift actors protect mutable state.")])
}

@Test @MainActor
func ocrReviewRejectsSentenceThatDoesNotContainPhrase() async {
    let explainer = ContextRecordingExplainer()
    let lookup = LookupCoordinator(explainer: explainer, preferences: UserDefaults(suiteName: UUID().uuidString)!)
    let flow = OCRLookupFlow(recognizer: ContextRecognizer(text: "Swift actors protect mutable state.\nAnother line."))
    await flow.start(lookup: lookup, hidePanel: {}, showPanel: {})

    await flow.confirm(lookup: lookup, selectedText: "actors", selectedSentence: "Another line.")
    #expect(flow.isReviewing)
    #expect(flow.errorMessage != nil)
    #expect(explainer.requests.isEmpty)
}

@MainActor private struct ContextTextReader: SelectedTextReading {
    let text: String
    func readSelectedText() async -> SelectionReadResult { .selected(text) }
}

@MainActor private struct ContextRecognizer: RegionTextRecognizing {
    let text: String
    func recognizeSelectedRegion() async throws -> OCRRecognition? { OCRRecognition(text: text, confidence: 0.95) }
}

@MainActor private final class ContextRecordingExplainer: LocalExplaining {
    var requests: [LookupRequest] = []
    func explain(_ request: LookupRequest) async throws -> LookupResult {
        requests.append(request)
        return LookupResult(meaning: "Meaning", example: "Example", detail: "")
    }
}
