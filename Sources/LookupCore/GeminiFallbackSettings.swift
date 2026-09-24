import Foundation
import Observation

/// A saved decision applies only when a Local lookup reports that it cannot run.
/// It never changes an explicitly selected lookup source.
public enum GeminiFallbackChoice: String, CaseIterable, Identifiable, Sendable {
    case ask
    case allow
    case decline

    public var id: String { rawValue }
}

@MainActor @Observable
public final class GeminiFallbackSettings {
    public static let storageKey = "gemini.localFallbackChoice"

    public var choice: GeminiFallbackChoice {
        didSet { defaults.set(choice.rawValue, forKey: Self.storageKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        choice = defaults.string(forKey: Self.storageKey)
            .flatMap(GeminiFallbackChoice.init(rawValue:)) ?? .ask
    }
}

/// Only availability failures can trigger a cloud fallback offer. A model or
/// translation error during an otherwise available lookup remains a Local error.
public protocol LocalLookupUnavailable: Error {}
