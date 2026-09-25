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
    /// Called as soon as a valid region is selected, before capture and OCR.
    /// A cancelled selection returns nil without calling this closure.
    func recognizeSelectedRegion(onSelection: @MainActor () async -> Void) async throws -> OCRRecognition?
}

@MainActor @Observable
public final class OCRLookupFlow {
    public private(set) var isSelecting = false
    public private(set) var isRecognizing = false
    public private(set) var isReviewing = false
    public private(set) var errorMessage: String?

    @ObservationIgnored private let recognizer: any RegionTextRecognizing

    public init(recognizer: any RegionTextRecognizing) {
        self.recognizer = recognizer
    }

    public func start(lookup: LookupCoordinator, hidePanel: () -> Void, showPanel: () async -> Void) async {
        guard !isSelecting && !isRecognizing else { return }
        isSelecting = true
        isRecognizing = false
        isReviewing = false
        errorMessage = nil
        hidePanel()
        var automaticText: String?
        var panelOpened = false

        do {
            if let recognition = try await recognizer.recognizeSelectedRegion(onSelection: {
                isSelecting = false
                isRecognizing = true
                await showPanel()
                panelOpened = true
            }) {
                let recognizedText = recognition.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if recognizedText.isEmpty {
                    errorMessage = "No readable text was found in the selected region. Try selecting a clearer area."
                } else if Self.isSafeToSubmitAutomatically(recognition) {
                    automaticText = recognizedText
                } else {
                    lookup.text = recognizedText
                    isReviewing = true
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            if !panelOpened { await showPanel() }
        }
        isSelecting = false
        isRecognizing = false
        if let automaticText {
            lookup.text = automaticText
            await lookup.submit()
        }
    }

    /// Conservative auto-submit rule: a single OCR line of at most four words,
    /// without sentence punctuation or ambiguous symbols, and strong confidence.
    static func isSafeToSubmitAutomatically(_ recognition: OCRRecognition) -> Bool {
        let text = recognition.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return recognition.confidence >= 0.90 && LookupCoordinator.isClearShortPhrase(text)
    }

    public func cancelReview() {
        isReviewing = false
        errorMessage = nil
    }
}
