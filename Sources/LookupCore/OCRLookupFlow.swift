import Foundation
import Observation

/// The capture implementation owns its image only for the duration of this call.
/// A nil result means the user cancelled region selection.
public struct OCRRecognition: Equatable, Sendable {
    public let text: String
    /// Lowest confidence among the recognized lines, on Vision's 0...1 scale.
    public let confidence: Float

    public init(text: String, confidence: Float) {
        self.text = text
        self.confidence = confidence
    }
}

@MainActor
public protocol RegionTextRecognizing {
    func recognizeSelectedRegion() async throws -> OCRRecognition?
}

@MainActor @Observable
public final class OCRLookupFlow {
    public private(set) var isSelecting = false
    public private(set) var isReviewing = false
    public private(set) var errorMessage: String?
    public var recognizedText = ""

    @ObservationIgnored private let recognizer: any RegionTextRecognizing

    public init(recognizer: any RegionTextRecognizing) {
        self.recognizer = recognizer
    }

    public func start(lookup: LookupCoordinator, hidePanel: () -> Void, showPanel: () -> Void) async {
        guard !isSelecting else { return }
        isSelecting = true
        isReviewing = false
        errorMessage = nil
        recognizedText = ""
        hidePanel()
        var automaticText: String?

        do {
            if let recognition = try await recognizer.recognizeSelectedRegion() {
                recognizedText = recognition.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if recognizedText.isEmpty {
                    errorMessage = "No readable text was found in the selected region. Try selecting a clearer area."
                } else if Self.isSafeToSubmitAutomatically(recognition) {
                    automaticText = recognizedText
                } else {
                    isReviewing = true
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSelecting = false
        showPanel()
        if let automaticText {
            lookup.text = automaticText
            await lookup.submit()
        }
    }

    /// Conservative auto-submit rule: a single OCR line of at most four words,
    /// without sentence punctuation or ambiguous symbols, and strong confidence.
    static func isSafeToSubmitAutomatically(_ recognition: OCRRecognition) -> Bool {
        let text = recognition.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard recognition.confidence >= 0.90,
              text.count <= 32,
              !text.contains(where: \.isNewline) else { return false }
        let words = text.split(whereSeparator: \.isWhitespace)
        guard (1...4).contains(words.count) else { return false }
        return words.allSatisfy { word in
            word.unicodeScalars.allSatisfy {
                CharacterSet.letters.contains($0) || $0 == "'" || $0 == "-"
            }
        }
    }

    public func confirm(lookup: LookupCoordinator, selectedText: String? = nil, selectedSentence: String? = nil) async {
        guard isReviewing else { return }
        let selected = (selectedText ?? recognizedText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let choice = SelectedLookupText(source: recognizedText, phrase: selected, sentence: selectedSentence) else {
            errorMessage = selected.isEmpty
                ? "Choose an English word or short phrase from the recognized text."
                : "Choose a phrase and optional sentence from the selected text. The sentence must contain the phrase."
            return
        }
        lookup.text = choice.phrase
        isReviewing = false
        errorMessage = nil
        await lookup.submit(selectedSentence: choice.sentence)
    }

    public func cancelReview() {
        isReviewing = false
        recognizedText = ""
        errorMessage = nil
    }
}
