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
    private static let selectionReadAttempts = 3
    private static let selectionReadRetryDelay = Duration.milliseconds(40)

    public private(set) var status: SelectionLookupStatus = .idle
    public private(set) var errorMessage: String?

    @ObservationIgnored private let reader: any SelectedTextReading

    public init(reader: any SelectedTextReading) {
        self.reader = reader
    }

    /// `onSelectionRead` runs right after the selection is stored and before the lookup
    /// is awaited, so callers can show UI while the request is in flight.
    public func start(lookup: LookupCoordinator, onSelectionRead: @MainActor () -> Void = {}) async {
        guard status != .reading else { return }
        status = .reading
        errorMessage = nil
        switch await readSelectedText() {
        case .selected(let text):
            let selected = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !selected.isEmpty else {
                status = .regionFallback
                return
            }
            lookup.text = selected
            onSelectionRead()
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

    private func readSelectedText() async -> SelectionReadResult {
        for attempt in 1...Self.selectionReadAttempts {
            let result = await reader.readSelectedText()
            guard result == .unavailable, attempt < Self.selectionReadAttempts else {
                return result
            }
            do {
                try await Task.sleep(for: Self.selectionReadRetryDelay)
            } catch {
                return .unavailable
            }
        }
        return .unavailable
    }

    public func reset() {
        guard status != .reading else { return }
        status = .idle
        errorMessage = nil
    }
}
