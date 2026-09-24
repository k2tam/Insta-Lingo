import Foundation
import Observation

public enum LookupSource: String, CaseIterable, Sendable {
    case local
    case gemini
}

@MainActor
public protocol GeminiLookupProviding {
    func lookup(_ request: LookupRequest, to target: TargetLanguage, apiKey: String) async throws -> LookupResult
}

@MainActor
public protocol GeminiCredentialStoring {
    func read() throws -> String?
    func save(_ key: String) throws
    func delete() throws
}

public enum GeminiConfigurationError: LocalizedError, Equatable {
    case disabled
    case missingKey
    case credentialStore

    public var errorDescription: String? {
        switch self {
        case .disabled: "Enable Gemini in settings before selecting it for a lookup."
        case .missingKey: "Add a Gemini API key in settings before using Gemini."
        case .credentialStore: "The Gemini API key could not be accessed in Keychain."
        }
    }
}

/// Consent is persisted, but the selected source belongs to one lookup session.
/// The API key lives only in the credential store, never in UserDefaults or history.
@MainActor @Observable
public final class GeminiConfiguration {
    public private(set) var isEnabled: Bool
    public private(set) var hasAPIKey: Bool

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let credentials: any GeminiCredentialStoring
    @ObservationIgnored private let enabledKey = "gemini.enabled"

    public init(defaults: UserDefaults = .standard, credentials: any GeminiCredentialStoring) {
        self.defaults = defaults
        self.credentials = credentials
        isEnabled = defaults.bool(forKey: enabledKey)
        hasAPIKey = (try? credentials.read())?.isEmpty == false
    }

    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: enabledKey)
    }

    public func saveAPIKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GeminiConfigurationError.missingKey }
        do {
            try credentials.save(trimmed)
            hasAPIKey = true
        } catch {
            throw GeminiConfigurationError.credentialStore
        }
    }

    public func removeAPIKey() throws {
        do {
            try credentials.delete()
            hasAPIKey = false
        } catch {
            throw GeminiConfigurationError.credentialStore
        }
    }

    public func keyForSelectedLookup() throws -> String {
        guard isEnabled else { throw GeminiConfigurationError.disabled }
        do {
            guard let key = try credentials.read(), !key.isEmpty else {
                hasAPIKey = false
                throw GeminiConfigurationError.missingKey
            }
            hasAPIKey = true
            return key
        } catch let error as GeminiConfigurationError {
            throw error
        } catch {
            throw GeminiConfigurationError.credentialStore
        }
    }
}
