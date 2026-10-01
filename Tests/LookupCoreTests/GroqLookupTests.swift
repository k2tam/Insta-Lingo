import Foundation
import Testing
@testable import LookupCore

@Test @MainActor
func localLookupNeverCallsGroqWhenExplicitlySelected() async throws {
    let defaults = UserDefaults(suiteName: "GroqLookupTests.\(UUID())")!
    let credentials = FakeGroqCredentials(key: "secret")
    let configuration = LookupModelConfiguration(credentials: credentials, preferences: defaults)
    let groq = RecordingGroq()
    let local = RecordingLocal()
    let lookup = LookupCoordinator(
        explainer: local,
        groq: groq,
        modelConfiguration: configuration,
        preferences: defaults
    )
    lookup.selectedLanguage = .simpleEnglish
    lookup.selectedSource = .local
    lookup.text = "actor"

    await lookup.submit()

    #expect(local.requests.map(\.text) == ["actor"])
    #expect(groq.calls.isEmpty)
    #expect(lookup.selectedSource == .local)
}

@Test @MainActor
func groqIsDefaultAndReceivesOnlySelectedLookupInputs() async throws {
    let defaults = UserDefaults(suiteName: "GroqLookupTests.\(UUID())")!
    let credentials = FakeGroqCredentials(key: "secret")
    let configuration = LookupModelConfiguration(credentials: credentials, preferences: defaults)
    let groq = RecordingGroq()
    let local = RecordingLocal()
    let lookup = LookupCoordinator(
        explainer: local,
        groq: groq,
        modelConfiguration: configuration,
        preferences: defaults
    )
    lookup.text = "  actor  "
    lookup.selectedLanguage = .vietnamese
    _ = lookup.contextCatalog.select(id: ProfessionalContext.swiftIOS.id)

    await lookup.submit()

    #expect(groq.calls.count == 1)
    #expect(groq.calls.first?.request.text == "actor")
    #expect(groq.calls.first?.request.context == .swiftIOS)
    #expect(groq.calls.first?.target == .vietnamese)
    #expect(groq.calls.first?.route == .builtIn(.gptOSS20B, .low))
    #expect(local.requests.isEmpty)
    #expect(lookup.phase == .result)
    #expect(lookup.selectedSource == .groq)
}

@Test @MainActor
func groqLooksUpWithoutPersonalKeyUsingBuiltInModel() async {
    let defaults = UserDefaults(suiteName: "GroqLookupTests.\(UUID())")!
    let configuration = LookupModelConfiguration(credentials: FakeGroqCredentials(), preferences: defaults)
    let groq = RecordingGroq()
    let lookup = LookupCoordinator(
        explainer: RecordingLocal(),
        groq: groq,
        modelConfiguration: configuration,
        preferences: defaults
    )
    lookup.text = "actor"

    await lookup.submit()

    #expect(groq.calls.count == 1)
    #expect(groq.calls.first?.route == .builtIn(.gptOSS20B, .low))
    #expect(lookup.phase == .result)
}

@Test @MainActor
func builtInModelAndEffortPersistAcrossConfigurationInstances() {
    let defaults = UserDefaults(suiteName: "GroqModelTests.\(UUID())")!
    let credentials = FakeGroqCredentials()
    let configuration = LookupModelConfiguration(credentials: credentials, preferences: defaults)

    #expect(configuration.selection == .builtIn(.gptOSS20B))
    #expect(configuration.reasoningEffort == .low)

    configuration.selection = .builtIn(.gptOSS20B)
    configuration.reasoningEffort = .high

    let restored = LookupModelConfiguration(credentials: credentials, preferences: defaults)
    #expect(restored.selection == .builtIn(.gptOSS20B))
    #expect(restored.reasoningEffort == .high)
    #expect(restored.selectedModelDisplayName == "GPT-OSS 20B")
}

@Test @MainActor
func customModelsPersistAndKeepKeysInTheirOwnAccounts() throws {
    let defaults = UserDefaults(suiteName: "GroqModelTests.\(UUID())")!
    let credentials = FakeGroqCredentials()
    let configuration = LookupModelConfiguration(credentials: credentials, preferences: defaults)
    let openAI = try CustomModel(name: " OpenAI ", baseURLString: "https://api.openai.com/v1", modelID: "gpt-4o-mini")
    let ollama = try CustomModel(name: "Ollama", baseURLString: "http://localhost:11434/v1", modelID: "llama3.2")

    try configuration.addCustomModel(openAI, apiKey: "  sk-openai  ")
    try configuration.addCustomModel(ollama, apiKey: nil)
    configuration.selection = .custom(openAI.id)

    #expect(openAI.name == "OpenAI")
    #expect(openAI.chatCompletionsURL.absoluteString == "https://api.openai.com/v1/chat/completions")
    #expect(credentials.keys[LookupModelConfiguration.keyAccount(for: openAI.id)] == "sk-openai")
    #expect(credentials.keys[LookupModelConfiguration.keyAccount(for: ollama.id)] == nil)
    #expect(configuration.hasAPIKey(for: openAI.id))
    #expect(!configuration.hasAPIKey(for: ollama.id))

    var renamed = openAI
    renamed.name = "OpenAI mini"
    try configuration.updateCustomModel(renamed, apiKey: nil)
    #expect(credentials.keys[LookupModelConfiguration.keyAccount(for: openAI.id)] == "sk-openai")

    let restored = LookupModelConfiguration(credentials: credentials, preferences: defaults)
    #expect(restored.customModels == [renamed, ollama])
    #expect(restored.selection == .custom(openAI.id))
    #expect(restored.selectedModelDisplayName == "OpenAI mini")
    #expect(restored.hasAPIKey(for: openAI.id))
    #expect(try restored.routeForLookup() == .custom(renamed, apiKey: "sk-openai"))

    try restored.updateCustomModel(renamed, apiKey: "")
    #expect(credentials.keys[LookupModelConfiguration.keyAccount(for: openAI.id)] == nil)
    #expect(try restored.routeForLookup() == .custom(renamed, apiKey: nil))

    try restored.deleteCustomModel(id: ollama.id)
    #expect(LookupModelConfiguration(credentials: credentials, preferences: defaults).customModels == [renamed])
}

@Test @MainActor
func deletingSelectedCustomModelFallsBackToBuiltIn() throws {
    let defaults = UserDefaults(suiteName: "GroqModelTests.\(UUID())")!
    let credentials = FakeGroqCredentials()
    let configuration = LookupModelConfiguration(credentials: credentials, preferences: defaults)
    let model = CustomModel(name: "OpenRouter", baseURL: URL(string: "https://openrouter.ai/api/v1")!, modelID: "x/y")
    try configuration.addCustomModel(model, apiKey: "secret")
    configuration.selection = .custom(model.id)

    try configuration.deleteCustomModel(id: model.id)

    #expect(configuration.selection == .builtIn(.gptOSS20B))
    #expect(credentials.keys.isEmpty)
    #expect(try configuration.routeForLookup() == .builtIn(.gptOSS20B, .low))
}

@Test @MainActor
func legacyGroqKeyIsDiscardedAndBuiltInStaysDefault() throws {
    let defaults = UserDefaults(suiteName: "GroqModelTests.\(UUID())")!
    defaults.set(GroqModel.gptOSS20B.rawValue, forKey: LookupModelConfiguration.legacyModelStorageKey)
    let credentials = FakeGroqCredentials(key: "gsk-legacy")

    let configuration = LookupModelConfiguration(credentials: credentials, preferences: defaults)

    #expect(configuration.customModels.isEmpty)
    #expect(configuration.selection == .builtIn(.gptOSS20B))
    #expect(credentials.keys.isEmpty)
    #expect(defaults.string(forKey: LookupModelConfiguration.legacyModelStorageKey) == nil)
    #expect(try configuration.routeForLookup() == .builtIn(.gptOSS20B, .low))
}

@Test @MainActor
func previouslyMigratedGroqModelIsRemoved() throws {
    let defaults = UserDefaults(suiteName: "GroqModelTests.\(UUID())")!
    let credentials = FakeGroqCredentials()
    let migrated = CustomModel(name: "Groq (your key)", baseURL: CustomModel.groqBaseURL, modelID: "openai/gpt-oss-120b")
    let own = CustomModel(name: "Groq", baseURL: CustomModel.groqBaseURL, modelID: "openai/gpt-oss-120b")
    let setup = LookupModelConfiguration(credentials: credentials, preferences: defaults)
    try setup.addCustomModel(migrated, apiKey: "gsk-legacy")
    try setup.addCustomModel(own, apiKey: "gsk-own")
    setup.selection = .custom(migrated.id)

    let configuration = LookupModelConfiguration(credentials: credentials, preferences: defaults)

    #expect(configuration.customModels == [own])
    #expect(configuration.selection == .builtIn(.gptOSS20B))
    #expect(credentials.keys[LookupModelConfiguration.keyAccount(for: migrated.id)] == nil)
    #expect(credentials.keys[LookupModelConfiguration.keyAccount(for: own.id)] == "gsk-own")
}

@Test
func customModelValidationAllowsPlainHTTPOnlyForLocalServers() throws {
    #expect(throws: LookupModelConfigurationError.insecureURL) {
        try CustomModel(name: "Remote", baseURLString: "http://example.com/v1", modelID: "m")
    }
    #expect(throws: LookupModelConfigurationError.invalidURL) {
        try CustomModel(name: "Bad", baseURLString: "ftp://example.com", modelID: "m")
    }
    #expect(throws: LookupModelConfigurationError.emptyName) {
        try CustomModel(name: "  ", baseURLString: "https://api.openai.com/v1", modelID: "m")
    }
    #expect(throws: LookupModelConfigurationError.emptyModelID) {
        try CustomModel(name: "OpenAI", baseURLString: "https://api.openai.com/v1", modelID: " ")
    }
    _ = try CustomModel(name: "Ollama", baseURLString: "http://localhost:11434/v1", modelID: "llama3.2")
    _ = try CustomModel(name: "LM Studio", baseURLString: "http://127.0.0.1:1234/v1", modelID: "qwen")
    _ = try CustomModel(name: "Box", baseURLString: "http://studio.local:1234/v1", modelID: "qwen")
}

@Test @MainActor
func cacheDoesNotReuseResultAcrossModels() async throws {
    let defaults = UserDefaults(suiteName: "GroqLookupTests.\(UUID())")!
    let configuration = LookupModelConfiguration(credentials: FakeGroqCredentials(), preferences: defaults)
    let model = CustomModel(name: "OpenAI", baseURL: URL(string: "https://api.openai.com/v1")!, modelID: "gpt-4o-mini")
    try configuration.addCustomModel(model, apiKey: "secret")
    let groq = RecordingGroq()
    let lookup = LookupCoordinator(
        explainer: RecordingLocal(), groq: groq, modelConfiguration: configuration, preferences: defaults
    )
    lookup.text = "actor"

    await lookup.submit()
    configuration.selection = .custom(model.id)
    await lookup.submit()
    configuration.selection = .builtIn(.gptOSS120B)
    await lookup.submit()

    #expect(groq.calls.map(\.route) == [
        .builtIn(.gptOSS120B, .low),
        .custom(model, apiKey: "secret"),
    ])
}

@Test @MainActor
func repeatedGroqLookupIsServedFromCacheUntilTargetOrContextChanges() async {
    let defaults = UserDefaults(suiteName: "GroqLookupTests.\(UUID())")!
    let configuration = LookupModelConfiguration(credentials: FakeGroqCredentials(key: "secret"), preferences: defaults)
    let groq = RecordingGroq()
    let lookup = LookupCoordinator(
        explainer: RecordingLocal(), groq: groq, modelConfiguration: configuration, preferences: defaults
    )
    lookup.selectedLanguage = .simpleEnglish
    lookup.text = "Actor"
    await lookup.submit()
    lookup.text = "actor"
    await lookup.submit()

    #expect(groq.calls.count == 1)
    #expect(lookup.phase == .result)
    #expect(lookup.completedLookup?.result.meaning == "diễn viên")

    lookup.selectedLanguage = .vietnamese
    await lookup.submit()
    #expect(groq.calls.count == 2)

    let other = lookup.contextCatalog.contexts.first { $0.id != lookup.contextCatalog.selectedContext.id }!
    _ = lookup.contextCatalog.select(id: other.id)
    await lookup.submit()
    #expect(groq.calls.count == 3)
}

@Test @MainActor
func quickMeaningUsesQuickDepthAndIsCachedSeparately() async throws {
    let defaults = UserDefaults(suiteName: "GroqLookupTests.\(UUID())")!
    let configuration = LookupModelConfiguration(credentials: FakeGroqCredentials(key: "secret"), preferences: defaults)
    let groq = RecordingGroq()
    let lookup = LookupCoordinator(
        explainer: RecordingLocal(), groq: groq, modelConfiguration: configuration, preferences: defaults
    )
    lookup.selectedLanguage = .vietnamese
    lookup.text = "actor"
    await lookup.submit()
    _ = try await lookup.quickMeaning(for: "actor")
    _ = try await lookup.quickMeaning(for: "actor")

    #expect(groq.calls.map(\.depth) == [.full, .quick])
}

/// Keys by Keychain account; `key` seeds the legacy single-key account.
@MainActor
private final class FakeGroqCredentials: GroqCredentialStoring {
    var keys: [String: String] = [:]

    init(key: String? = nil) {
        keys[LookupModelConfiguration.legacyKeyAccount] = key
    }

    func read(account: String) throws -> String? { keys[account] }
    func save(_ key: String, account: String) throws { keys[account] = key }
    func delete(account: String) throws { keys[account] = nil }
}

@MainActor
private final class RecordingGroq: GroqLookupProviding {
    struct Call {
        let request: LookupRequest
        let target: TargetLanguage
        let route: LookupRoute
        let depth: LookupDepth
    }

    var calls: [Call] = []

    func lookup(_ request: LookupRequest, to target: TargetLanguage, route: LookupRoute, depth: LookupDepth) async throws -> LookupResult {
        calls.append(Call(request: request, target: target, route: route, depth: depth))
        return LookupResult(meaning: "diễn viên", example: "An actor runs on the main thread.", detail: "")
    }
}

@MainActor
private final class RecordingLocal: LocalExplaining {
    var requests: [LookupRequest] = []

    func explain(_ request: LookupRequest) async throws -> LookupResult {
        requests.append(request)
        return LookupResult(meaning: "local", example: "example", detail: "")
    }
}
