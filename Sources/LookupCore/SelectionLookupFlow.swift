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
    public private(set) var errorMessage: String?

    @ObservationIgnored private let reader: any SelectedTextReading

    public init(reader: any SelectedTextReading) {
        self.reader = reader
    }

    public func start(lookup: LookupCoordinator) async {
        guard status != .reading else { return }
        status = .reading
        errorMessage = nil
        switch await reader.readSelectedText() {
        case .selected(let text):
            let selected = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !selected.isEmpty else {
                status = .regionFallback
                return
            }
            lookup.text = selected
            if !LookupCoordinator.isClearShortPhrase(selected) {
                status = .reviewing
            } else {
                status = .idle
                await lookup.submit()
            }
        case .permissionRequired:
            status = .permissionRequired
        case .unavailable:
            status = .regionFallback
        }
    }

    public func reset() {
        guard status != .reading else { return }
        status = .idle
        errorMessage = nil
    }
}
