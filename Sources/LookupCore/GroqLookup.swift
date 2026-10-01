import Foundation
import Observation

/// `.groq` is kept as the persisted value for "an AI model" so stored preferences stay valid.
public enum LookupSource: String, CaseIterable, Sendable {
    case local
    case groq
}

/// Built-in models served through the app's proxy. Add a case here when a new
/// model has been verified to support the lookup request and JSON response format.
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

    /// The 120B model is pinned to low effort; only the 20B model lets the user choose.
    public var supportedEfforts: [GroqReasoningEffort] {
        switch self {
        case .gptOSS120B: [.low]
        case .gptOSS20B: GroqReasoningEffort.allCases
        }
    }

    public var isEffortSelectable: Bool { supportedEfforts.count > 1 }

    public func effectiveEffort(_ preferred: GroqReasoningEffort) -> GroqReasoningEffort {
        supportedEfforts.contains(preferred) ? preferred : .low
    }
}

public enum GroqReasoningEffort: String, CaseIterable, Identifiable, Sendable {
    case low
    case medium
    case high

    public var id: String { rawValue }
}

/// `.quick` asks only for a short meaning; built-in lookups use the small, fast model.
public enum LookupDepth: Hashable, Sendable {
    case full
    case quick
}

/// A user-added OpenAI-compatible endpoint. Its API key lives only in Keychain.
public struct CustomModel: Codable, Identifiable, Hashable, Sendable {
    public static let groqBaseURL = URL(string: "https://api.groq.com/openai/v1")!

    public let id: UUID
    public var name: String
    public var baseURL: URL
    public var modelID: String

    public var chatCompletionsURL: URL { baseURL.appending(path: "chat/completions") }

    public init(id: UUID = UUID(), name: String, baseURL: URL, modelID: String) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.modelID = modelID
    }

    /// Builds a validated model from the editor's text fields.
    public init(id: UUID = UUID(), name: String, baseURLString: String, modelID: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModelID = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw LookupModelConfigurationError.emptyName }
        guard let url = URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw LookupModelConfigurationError.invalidURL
        }
        self.init(id: id, name: trimmedName, baseURL: url, modelID: trimmedModelID)
        try validate()
    }

    /// Plain HTTP is allowed only for servers on this Mac or the local network.
    public func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LookupModelConfigurationError.emptyName
        }
        guard let scheme = baseURL.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = baseURL.host()?.lowercased(), !host.isEmpty else {
            throw LookupModelConfigurationError.invalidURL
        }
        if scheme == "http", host != "localhost", host != "127.0.0.1", !host.hasSuffix(".local") {
            throw LookupModelConfigurationError.insecureURL
        }
        guard !modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LookupModelConfigurationError.emptyModelID
        }
    }
}

public enum LookupModelSelection: Hashable, Sendable {
    case builtIn(GroqModel)
    case custom(UUID)

    var storageValue: String {
        switch self {
        case .builtIn(let model): "builtin:\(model.rawValue)"
        case .custom(let id): "custom:\(id.uuidString)"
        }
    }

    init?(storageValue: String) {
        guard let separator = storageValue.firstIndex(of: ":") else { return nil }
        let value = String(storageValue[storageValue.index(after: separator)...])
        switch storageValue[..<separator] {
        case "builtin":
            guard let model = GroqModel(rawValue: value) else { return nil }
            self = .builtIn(model)
        case "custom":
            guard let id = UUID(uuidString: value) else { return nil }
            self = .custom(id)
        default:
            return nil
        }
    }
}

/// What the provider needs for one lookup.
public enum LookupRoute: Equatable, Sendable {
    /// Goes through the app's proxy with the built-in key.
    case builtIn(GroqModel, GroqReasoningEffort)
    /// Goes directly to the user's endpoint.
    case custom(CustomModel, apiKey: String?)

    /// Distinguishes routes whose answers may differ, for caching.
    public var cacheIdentity: String {
        switch self {
        case .builtIn(let model, let effort): "builtin:\(model.rawValue):\(effort.rawValue)"
        case .custom(let model, _): "custom:\(model.id.uuidString):\(model.modelID)@\(model.baseURL.absoluteString)"
        }
    }
}

@MainActor
public protocol GroqLookupProviding {
    func lookup(_ request: LookupRequest, to target: TargetLanguage, route: LookupRoute, depth: LookupDepth) async throws -> LookupResult
}

public extension GroqLookupProviding {
    func lookup(_ request: LookupRequest, to target: TargetLanguage, route: LookupRoute) async throws -> LookupResult {
        try await lookup(request, to: target, route: route, depth: .full)
    }
}

@MainActor
public protocol GroqCredentialStoring {
    func read(account: String) throws -> String?
    func save(_ key: String, account: String) throws
    func delete(account: String) throws
}

public enum LookupModelConfigurationError: LocalizedError, Equatable {
    case emptyName
    case emptyModelID
    case invalidURL
    case insecureURL
    case credentialStore

    public var errorDescription: String? {
        switch self {
        case .emptyName: "Enter a name for this model."
        case .emptyModelID: "Enter the model ID."
        case .invalidURL: "Enter a base URL that starts with https://."
        case .insecureURL: "Use https://. Plain http:// is allowed only for localhost, 127.0.0.1 or .local servers."
        case .credentialStore: "The API key could not be accessed in Keychain."
        }
    }
}

/// API keys live only in Keychain, never in UserDefaults or lookup history.
@MainActor @Observable
public final class LookupModelConfiguration {
    public static let selectionStorageKey = "lookup.model"
    public static let customModelsStorageKey = "lookup.customModels"
    public static let effortStorageKey = "groq.reasoningEffort"
    public static let legacyModelStorageKey = "groq.model"
    public static let legacyKeyAccount = "api-key"
    static let legacyMigratedModelName = "Groq (your key)"
    public static let fallbackSelection = LookupModelSelection.builtIn(.gptOSS20B)

    public static func keyAccount(for id: UUID) -> String { "custom.\(id.uuidString)" }

    public var selection: LookupModelSelection {
        didSet { preferences.set(selection.storageValue, forKey: Self.selectionStorageKey) }
    }
    /// Applies only to built-in models.
    public var reasoningEffort: GroqReasoningEffort {
        didSet { preferences.set(reasoningEffort.rawValue, forKey: Self.effortStorageKey) }
    }
    public private(set) var customModels: [CustomModel] {
        didSet { persistCustomModels() }
    }
    private var modelsWithKey: Set<UUID> = []

    @ObservationIgnored private let credentials: any GroqCredentialStoring
    @ObservationIgnored private let preferences: UserDefaults

    public init(credentials: any GroqCredentialStoring, preferences: UserDefaults = .standard) {
        self.credentials = credentials
        self.preferences = preferences
        reasoningEffort = preferences.string(forKey: Self.effortStorageKey)
            .flatMap(GroqReasoningEffort.init(rawValue:)) ?? .low
        customModels = preferences.data(forKey: Self.customModelsStorageKey)
            .flatMap { try? JSONDecoder().decode([CustomModel].self, from: $0) } ?? []
        let legacyModel = preferences.string(forKey: Self.legacyModelStorageKey)
        selection = preferences.string(forKey: Self.selectionStorageKey)
            .flatMap(LookupModelSelection.init(storageValue:))
            ?? legacyModel.flatMap(GroqModel.init(rawValue:)).map(LookupModelSelection.builtIn)
            ?? Self.fallbackSelection
        removeLegacyGroqKey()
        preferences.removeObject(forKey: Self.legacyModelStorageKey)
        modelsWithKey = Set(customModels.filter { model in
            (try? credentials.read(account: Self.keyAccount(for: model.id)))?.isEmpty == false
        }.map(\.id))
        if case .custom = selection, selectedCustomModel == nil {
            selection = Self.fallbackSelection
        }
    }

    public var selectedCustomModel: CustomModel? {
        guard case .custom(let id) = selection else { return nil }
        return customModels.first { $0.id == id }
    }

    public var selectedModelDisplayName: String {
        switch selection {
        case .builtIn(let model): model.displayName
        case .custom: selectedCustomModel?.name ?? GroqModel.gptOSS20B.displayName
        }
    }

    public func hasAPIKey(for id: UUID) -> Bool { modelsWithKey.contains(id) }

    public func addCustomModel(_ model: CustomModel, apiKey: String?) throws {
        try model.validate()
        try storeKey(apiKey, for: model.id)
        customModels.append(model)
    }

    /// A nil key leaves the saved key unchanged; an empty key removes it.
    public func updateCustomModel(_ model: CustomModel, apiKey: String?) throws {
        try model.validate()
        guard let index = customModels.firstIndex(where: { $0.id == model.id }) else { return }
        try storeKey(apiKey, for: model.id)
        customModels[index] = model
    }

    public func deleteCustomModel(id: UUID) throws {
        do {
            try credentials.delete(account: Self.keyAccount(for: id))
        } catch {
            throw LookupModelConfigurationError.credentialStore
        }
        modelsWithKey.remove(id)
        customModels.removeAll { $0.id == id }
        if selection == .custom(id) { selection = Self.fallbackSelection }
    }

    /// Falls back to the built-in model when the selected custom model no longer exists.
    public func routeForLookup() throws -> LookupRoute {
        if case .custom = selection, selectedCustomModel == nil {
            selection = Self.fallbackSelection
        }
        guard let model = selectedCustomModel else {
            guard case .builtIn(let builtIn) = selection else { return .builtIn(.gptOSS20B, reasoningEffort) }
            return .builtIn(builtIn, builtIn.effectiveEffort(reasoningEffort))
        }
        let key: String?
        do {
            key = try credentials.read(account: Self.keyAccount(for: model.id))
        } catch {
            throw LookupModelConfigurationError.credentialStore
        }
        let usableKey = key?.isEmpty == false ? key : nil
        if usableKey == nil { modelsWithKey.remove(model.id) } else { modelsWithKey.insert(model.id) }
        return .custom(model, apiKey: usableKey)
    }

    private func storeKey(_ apiKey: String?, for id: UUID) throws {
        guard let apiKey else { return }
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let account = Self.keyAccount(for: id)
        do {
            if trimmed.isEmpty {
                try credentials.delete(account: account)
                modelsWithKey.remove(id)
            } else {
                try credentials.save(trimmed, account: account)
                modelsWithKey.insert(id)
            }
        } catch {
            throw LookupModelConfigurationError.credentialStore
        }
    }

    /// The Groq key saved by an earlier version is the app's own default key, now held by the proxy.
    /// Deletes it, and the "Groq (your key)" model an earlier build created from it.
    private func removeLegacyGroqKey() {
        try? credentials.delete(account: Self.legacyKeyAccount)
        let migrated = customModels.filter {
            $0.name == Self.legacyMigratedModelName && $0.baseURL == CustomModel.groqBaseURL
        }
        guard !migrated.isEmpty else { return }
        for model in migrated {
            try? credentials.delete(account: Self.keyAccount(for: model.id))
        }
        let ids = Set(migrated.map(\.id))
        customModels.removeAll { ids.contains($0.id) }
    }

    private func persistCustomModels() {
        guard let data = try? JSONEncoder().encode(customModels) else { return }
        preferences.set(data, forKey: Self.customModelsStorageKey)
    }
}
