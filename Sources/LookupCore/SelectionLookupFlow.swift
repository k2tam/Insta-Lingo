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
    // Chromium/Electron apps build their accessibility tree only after the
    // reader asks for it, and Safari's web process can briefly refuse AX calls.
    private static let selectionReadAttempts = 5
    private static let selectionReadRetryDelay = Duration.milliseconds(80)
    static let fallbackFirstAppsKey = "selection.fallbackFirstApps"

    public private(set) var status: SelectionLookupStatus = .idle
    public private(set) var errorMessage: String?

    @ObservationIgnored private let reader: any SelectedTextReading
    @ObservationIgnored private let fallbackReader: (any SelectedTextReading)?
    @ObservationIgnored private let sourceAppID: @MainActor () -> String?
    @ObservationIgnored private let preferences: UserDefaults

    /// `fallbackReader` is tried once, only after every `reader` attempt
    /// reports the selection unavailable. Apps where that happened are
    /// remembered by `sourceAppID` so later reads start with the fallback.
    public init(
        reader: any SelectedTextReading,
        fallbackReader: (any SelectedTextReading)? = nil,
        sourceAppID: @escaping @MainActor () -> String? = { nil },
        preferences: UserDefaults = .standard
    ) {
        self.reader = reader
        self.fallbackReader = fallbackReader
        self.sourceAppID = sourceAppID
        self.preferences = preferences
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
        guard let fallbackReader else { return await readWithRetries() }
        let appID = sourceAppID()

        if let appID, fallbackFirstApps.contains(appID) {
            let fallbackResult = await fallbackReader.readSelectedText()
            guard fallbackResult == .unavailable else { return fallbackResult }
            // Only forget the app when the primary reader proves it works
            // again; both failing just means nothing was selected.
            let result = await readWithRetries()
            if case .selected = result { setFallbackFirst(false, for: appID) }
            return result
        }

        let result = await readWithRetries()
        guard result == .unavailable else { return result }
        let fallbackResult = await fallbackReader.readSelectedText()
        if case .selected = fallbackResult, let appID { setFallbackFirst(true, for: appID) }
        return fallbackResult
    }

    private var fallbackFirstApps: Set<String> {
        Set(preferences.stringArray(forKey: Self.fallbackFirstAppsKey) ?? [])
    }

    private func setFallbackFirst(_ enabled: Bool, for appID: String) {
        var apps = fallbackFirstApps
        if enabled { apps.insert(appID) } else { apps.remove(appID) }
        preferences.set(apps.sorted(), forKey: Self.fallbackFirstAppsKey)
    }

    private func readWithRetries() async -> SelectionReadResult {
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
