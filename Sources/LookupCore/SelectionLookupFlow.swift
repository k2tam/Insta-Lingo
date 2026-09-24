import Foundation
import Observation

public enum SelectionReadResult: Equatable, Sendable {
    case selected(String)
    case permissionRequired
    case unavailable
}

@MainActor
public protocol SelectedTextReading {
    /// Reads only text explicitly selected in the previously active application.
    func readSelectedText() async -> SelectionReadResult
}

public enum SelectionLookupStatus: Equatable, Sendable {
    case idle
    case reading
    case reviewing
    case permissionRequired
    case regionFallback
}

@MainActor @Observable
public final class SelectionLookupFlow {
    public private(set) var status: SelectionLookupStatus = .idle
    public private(set) var selectedText = ""
    public private(set) var errorMessage: String?

    @ObservationIgnored private let reader: any SelectedTextReading

    public init(reader: any SelectedTextReading) {
        self.reader = reader
    }

    public func start(lookup: LookupCoordinator, reviewSelection: Bool = false) async {
        guard status != .reading else { return }
        status = .reading
        selectedText = ""
        errorMessage = nil
        switch await reader.readSelectedText() {
        case .selected(let text):
            let selected = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !selected.isEmpty else {
                status = .regionFallback
                return
            }
            if reviewSelection {
                selectedText = selected
                status = .reviewing
            } else {
                lookup.text = selected
                status = .idle
                await lookup.submit()
            }
        case .permissionRequired:
            status = .permissionRequired
        case .unavailable:
            status = .regionFallback
        }
    }

    public func confirm(lookup: LookupCoordinator, phrase: String, sentence: String? = nil) async {
        guard status == .reviewing else { return }
        guard let choice = SelectedLookupText(source: selectedText, phrase: phrase, sentence: sentence) else {
            errorMessage = "Choose a phrase and optional sentence from the selected text. The sentence must contain the phrase."
            return
        }
        lookup.text = choice.phrase
        errorMessage = nil
        status = .idle
        await lookup.submit(selectedSentence: choice.sentence)
    }

    public func reset() {
        guard status != .reading else { return }
        status = .idle
        selectedText = ""
        errorMessage = nil
    }
}
