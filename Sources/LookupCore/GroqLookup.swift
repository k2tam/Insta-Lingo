import Foundation
import Observation

public enum LookupSource: String, CaseIterable, Sendable {
    case local
    case groq
}

/// Models offered by the app. Add a case here when a new model has been
/// verified to support the lookup request and JSON response format.
public enum GroqModel: String, CaseIterable, Identifiable, Sendable {
    case gptOSS120B = "openai/gpt-oss-120b"
    case gptOSS20B = "openai/gpt-oss-20b"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .gptOSS120B: "GPT-OSS 120B"
        case .gptOSS20B: "GPT-OSS 20B"
        }
    }

    public var supportedEfforts: [GroqReasoningEffort] { GroqReasoningEffort.allCases }
}

public enum GroqReasoningEffort: String, CaseIterable, Identifiable, Sendable {
    case low
    case medium
    case high

    public var id: String { rawValue }
}

@MainActor
public protocol GroqLookupProviding {
    func lookup(_ request: LookupRequest, to target: TargetLanguage, apiKey: String) async throws -> LookupResult
}

@MainActor
public protocol GroqCredentialStoring {
    func read() throws -> String?
    func save(_ key: String) throws
    func delete() throws
}

public enum GroqConfigurationError: LocalizedError, Equatable {
    case missingKey
    case credentialStore

    public var errorDescription: String? {
        switch self {
        case .missingKey: "Add a Groq API key in settings before using Groq."
        case .credentialStore: "The Groq API key could not be accessed in Keychain."
        }
    }
}

/// The API key lives only in Keychain, never in UserDefaults or lookup history.
@MainActor @Observable
public final class GroqConfiguration {
    public static let modelStorageKey = "groq.model"
    public static let effortStorageKey = "groq.reasoningEffort"

    public private(set) var hasAPIKey: Bool
    public var model: GroqModel {
        didSet {
            preferences.set(model.rawValue, forKey: Self.modelStorageKey)
            if let first = model.supportedEfforts.first,
               !model.supportedEfforts.contains(reasoningEffort) {
                reasoningEffort = first
            }
        }
    }
    public var reasoningEffort: GroqReasoningEffort {
        didSet { preferences.set(reasoningEffort.rawValue, forKey: Self.effortStorageKey) }
    }

    @ObservationIgnored private let credentials: any GroqCredentialStoring
    @ObservationIgnored private let preferences: UserDefaults

    public init(credentials: any GroqCredentialStoring, preferences: UserDefaults = .standard) {
        self.credentials = credentials
        self.preferences = preferences
        hasAPIKey = (try? credentials.read())?.isEmpty == false
        model = preferences.string(forKey: Self.modelStorageKey)
            .flatMap(GroqModel.init(rawValue:)) ?? .gptOSS120B
        reasoningEffort = preferences.string(forKey: Self.effortStorageKey)
            .flatMap(GroqReasoningEffort.init(rawValue:)) ?? .medium
        if let first = model.supportedEfforts.first,
           !model.supportedEfforts.contains(reasoningEffort) {
            reasoningEffort = first
        }
    }

    public func saveAPIKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GroqConfigurationError.missingKey }
        do {
            try credentials.save(trimmed)
            hasAPIKey = true
        } catch {
            throw GroqConfigurationError.credentialStore
        }
    }

    public func removeAPIKey() throws {
        do {
            try credentials.delete()
            hasAPIKey = false
        } catch {
            throw GroqConfigurationError.credentialStore
        }
    }

    public func keyForLookup() throws -> String {
        do {
            guard let key = try credentials.read(), !key.isEmpty else {
                hasAPIKey = false
                throw GroqConfigurationError.missingKey
            }
            hasAPIKey = true
            return key
        } catch let error as GroqConfigurationError {
            throw error
        } catch {
            throw GroqConfigurationError.credentialStore
        }
    }
}
