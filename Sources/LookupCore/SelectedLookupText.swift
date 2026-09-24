import Foundation

/// A lookup phrase and optional surrounding sentence taken only from text the
/// user explicitly selected in another app or a screen region.
public struct SelectedLookupText: Equatable, Sendable {
    public let phrase: String
    public let sentence: String?

    public init?(source: String, phrase: String, sentence: String? = nil) {
        let phrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty, source.range(of: phrase) != nil else { return nil }

        let sentence = sentence?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let sentence, !sentence.isEmpty {
            guard source.range(of: sentence) != nil,
                  sentence.range(of: phrase) != nil else { return nil }
            self.sentence = sentence
        } else {
            self.sentence = nil
        }
        self.phrase = phrase
    }
}
