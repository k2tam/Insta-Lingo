import Foundation

/// A lookup phrase taken from text the user selected in another app or a screen region.
public struct SelectedLookupText: Equatable, Sendable {
    public let phrase: String

    public init?(source: String, phrase: String) {
        let phrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty, source.range(of: phrase) != nil else { return nil }
        self.phrase = phrase
    }
}
