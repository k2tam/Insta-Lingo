import Foundation
import Observation

public struct LookupRequest: Equatable, Sendable {
    public let text: String
    public let context: ProfessionalContext
    public let selectedSentence: String?

    public init(text: String, context: ProfessionalContext = .general, selectedSentence: String? = nil) {
        self.text = text
        self.context = context
        self.selectedSentence = selectedSentence
    }
}

public struct LookupResult: Equatable, Sendable {
    public let meaning: String
    public let example: String
    public let detail: String

    public init(meaning: String, example: String, detail: String) {
        self.meaning = meaning
        self.example = example
        self.detail = detail
    }
}

public struct CompletedLookup: Equatable, Sendable {
    public let request: LookupRequest
    public let targetLanguage: TargetLanguage
    public let result: LookupResult

    public init(request: LookupRequest, targetLanguage: TargetLanguage, result: LookupResult) {
        self.request = request
        self.targetLanguage = targetLanguage
        self.result = result
    }
}

@MainActor
public protocol LocalExplaining {
    func explain(_ request: LookupRequest) async throws -> LookupResult
}

public struct TargetLanguage: Hashable, Identifiable, Sendable {
    public static let simpleEnglish = TargetLanguage(code: "en")
    public static let vietnamese = TargetLanguage(code: "vi")

    public let code: String
    public var id: String { code }
    public var isSimpleEnglish: Bool { code == "en" }

    public var displayName: String {
        if isSimpleEnglish { return "Simple English" }
        return Locale.current.localizedString(forLanguageCode: code) ?? code
    }

    public init(code: String) {
        self.code = code
    }
}

@MainActor
public protocol LocalTranslating {
    func supportedTargetLanguages() async -> [TargetLanguage]
    func translate(_ request: LookupRequest, to target: TargetLanguage) async throws -> LookupResult
}

public enum LookupPhase: Equatable, Sendable {
    case idle
    case loading
    case fallbackPrompt(String)
    case result
    case error(String)
}

@MainActor @Observable
public final class LookupCoordinator {
    public var text = ""
    /// Selecting Gemini applies to the next submission only.
    public var selectedSource: LookupSource = .local
    public let contextCatalog: ProfessionalContextCatalog
    public var selectedLanguage: TargetLanguage {
        didSet { preferences.set(selectedLanguage.code, forKey: Self.languageKey) }
    }
    public private(set) var availableLanguages: [TargetLanguage] = [.vietnamese, .simpleEnglish]
    public private(set) var phase: LookupPhase = .idle
    public private(set) var result: LookupResult?
    public private(set) var completedLookup: CompletedLookup?

    @ObservationIgnored private let explainer: any LocalExplaining
    @ObservationIgnored private let translator: (any LocalTranslating)?
    @ObservationIgnored private let gemini: (any GeminiLookupProviding)?
    @ObservationIgnored private let geminiConfiguration: GeminiConfiguration?
    @ObservationIgnored private let fallbackSettings: GeminiFallbackSettings?
    @ObservationIgnored private let history: LookupHistory?
    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private var pendingFallback: PendingFallback?
    private static let languageKey = "lookup.targetLanguage"

    public init(explainer: any LocalExplaining, translator: (any LocalTranslating)? = nil, gemini: (any GeminiLookupProviding)? = nil, geminiConfiguration: GeminiConfiguration? = nil, fallbackSettings: GeminiFallbackSettings? = nil, history: LookupHistory? = nil, preferences: UserDefaults = .standard, contextCatalog: ProfessionalContextCatalog? = nil) {
        self.explainer = explainer
        self.translator = translator
        self.gemini = gemini
        self.geminiConfiguration = geminiConfiguration
        self.fallbackSettings = fallbackSettings
        self.history = history
        self.preferences = preferences
        self.contextCatalog = contextCatalog ?? ProfessionalContextCatalog(defaults: preferences)
        let saved = preferences.string(forKey: Self.languageKey)
        selectedLanguage = saved.map(TargetLanguage.init(code:)) ?? .vietnamese
        if selectedLanguage != .vietnamese && selectedLanguage != .simpleEnglish {
            availableLanguages.append(selectedLanguage)
        }
    }

    public func loadAvailableLanguages() async {
        guard let translator else { return }
        let supported = await translator.supportedTargetLanguages()
        let options = Set(supported + [.simpleEnglish, .vietnamese, selectedLanguage])
        availableLanguages = options.sorted {
            if $0 == .vietnamese { return true }
            if $1 == .vietnamese { return false }
            if $0 == .simpleEnglish { return true }
            if $1 == .simpleEnglish { return false }
            return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    public func submit(selectedSentence: String? = nil) async {
        guard phase != .loading else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            phase = .error("Enter an English word or short phrase to look up.")
            return
        }
        phase = .loading
        result = nil
        completedLookup = nil
        pendingFallback = nil
        let source = selectedSource
        defer { selectedSource = .local }
        let request = LookupRequest(text: trimmed, context: contextCatalog.selectedContext, selectedSentence: selectedSentence)
        let target = selectedLanguage
        do {
            if source == .gemini {
                guard let gemini, let geminiConfiguration else {
                    throw GeminiConfigurationError.disabled
                }
                let key = try geminiConfiguration.keyForSelectedLookup()
                result = try await gemini.lookup(request, to: target, apiKey: key)
            } else if target.isSimpleEnglish {
                result = try await explainer.explain(request)
            } else if let translator {
                result = try await translator.translate(request, to: target)
            } else {
                throw LookupError.translationUnavailable
            }
            phase = .result
            if let result {
                completedLookup = CompletedLookup(request: request, targetLanguage: target, result: result)
                record(request: request, target: target, result: result)
            }
        } catch {
            if source == .local, error is LocalLookupUnavailable,
               let gemini, let geminiConfiguration, let fallbackSettings,
               geminiConfiguration.isEnabled, geminiConfiguration.hasAPIKey,
               (try? geminiConfiguration.keyForSelectedLookup()) != nil {
                switch fallbackSettings.choice {
                case .ask:
                    pendingFallback = PendingFallback(request: request, target: target, reason: error.localizedDescription)
                    phase = .fallbackPrompt(error.localizedDescription)
                case .allow:
                    await runFallback(request: request, target: target, gemini: gemini, configuration: geminiConfiguration)
                case .decline:
                    phase = .error(error.localizedDescription)
                }
            } else {
                phase = .error(error.localizedDescription)
            }
        }
    }

    /// Called only after the user responds to the visible Local-unavailable offer.
    public func resolveFallback(_ choice: GeminiFallbackChoice) async {
        guard choice != .ask, let pendingFallback, let fallbackSettings else { return }
        self.pendingFallback = nil
        fallbackSettings.choice = choice
        guard choice == .allow, let gemini, let geminiConfiguration else {
            phase = .error(pendingFallback.reason)
            return
        }
        await runFallback(request: pendingFallback.request, target: pendingFallback.target, gemini: gemini, configuration: geminiConfiguration)
    }

    private func runFallback(request: LookupRequest, target: TargetLanguage, gemini: any GeminiLookupProviding, configuration: GeminiConfiguration) async {
        phase = .loading
        do {
            let key = try configuration.keyForSelectedLookup()
            let value = try await gemini.lookup(request, to: target, apiKey: key)
            result = value
            phase = .result
            completedLookup = CompletedLookup(request: request, targetLanguage: target, result: value)
            record(request: request, target: target, result: value)
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    private func record(request: LookupRequest, target: TargetLanguage, result: LookupResult) {
        // Saving history is optional and must not replace a successful result.
        try? history?.record(text: request.text, targetLanguage: target, context: request.context, result: result)
    }
}

private struct PendingFallback {
    let request: LookupRequest
    let target: TargetLanguage
    let reason: String
}

private enum LookupError: LocalizedError, LocalLookupUnavailable {
    case translationUnavailable

    var errorDescription: String? {
        "Local translation is unavailable on this Mac. Your lookup was not sent to another provider."
    }
}
