import Foundation
import Testing
@testable import LookupCore

@Test @MainActor
func selectedPassageUsesOnlyChosenPhraseAndProfessionalContext() async {
    let source = "A Swift actor protects mutable state."
    let explainer = ContextRecordingExplainer()
    let lookup = LookupCoordinator(explainer: explainer, preferences: UserDefaults(suiteName: UUID().uuidString)!)
    lookup.selectedLanguage = .simpleEnglish
    lookup.contextCatalog.select(id: ProfessionalContext.swiftIOS.id)
    let flow = SelectionLookupFlow(reader: ContextTextReader(text: source))

    await flow.start(lookup: lookup)
    #expect(flow.status == .reviewing)
    #expect(lookup.text == source)
    #expect(explainer.requests.isEmpty)

    await lookup.submit(selectedPhrase: "actor")
    #expect(lookup.text == "actor")
    #expect(explainer.requests == [LookupRequest(text: "actor", context: .swiftIOS)])
}

@Test @MainActor
func ocrPassageUsesOnlyChosenPhraseAndProfessionalContext() async {
    let explainer = ContextRecordingExplainer()
    let lookup = LookupCoordinator(explainer: explainer, preferences: UserDefaults(suiteName: UUID().uuidString)!)
    lookup.selectedLanguage = .simpleEnglish
    lookup.contextCatalog.select(id: ProfessionalContext.softwareDevelopment.id)
    let source = "Swift actors protect mutable state.\nAnother line."
    let flow = OCRLookupFlow(recognizer: ContextRecognizer(text: source))

    await flow.start(lookup: lookup, hidePanel: {}, showPanel: {})
    #expect(flow.isReviewing)
    #expect(lookup.text == source)

    await lookup.submit(selectedPhrase: "actors")
    #expect(lookup.text == "actors")
    #expect(explainer.requests == [LookupRequest(text: "actors", context: .softwareDevelopment)])
}

@MainActor private struct ContextTextReader: SelectedTextReading {
    let text: String
    func readSelectedText() async -> SelectionReadResult { .selected(text) }
}

@MainActor private struct ContextRecognizer: RegionTextRecognizing {
    let text: String
    func recognizeSelectedRegion(onSelection: @MainActor () async -> Void) async throws -> OCRRecognition? {
        await onSelection()
        return OCRRecognition(text: text, confidence: 0.95)
    }
}

@MainActor private final class ContextRecordingExplainer: LocalExplaining {
    var requests: [LookupRequest] = []
    func explain(_ request: LookupRequest) async throws -> LookupResult {
        requests.append(request)
        return LookupResult(meaning: "Meaning", example: "Example", detail: "")
    }
}
