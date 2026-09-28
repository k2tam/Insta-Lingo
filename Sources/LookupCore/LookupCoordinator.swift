import Foundation
import Observation

public struct LookupRequest: Equatable, Sendable {
    public let text: String
    public let context: ProfessionalContext

    public init(text: String, context: ProfessionalContext = .general) {
        self.text = text
        self.context = context
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

/// Marks failures caused by an unavailable Apple on-device capability.
public protocol LocalLookupUnavailable: Error {}

public enum LookupPhase: Equatable, Sendable {
    case idle
    case loading
    case result
    case error(String)
}

@MainActor @Observable
public final class LookupCoordinator {
    public var text = "" {
        didSet {
            guard text != oldValue else { return }
            requestGeneration += 1
            phase = .idle
            result = nil
            completedLookup = nil
            vietnameseResult = nil
            vietnamesePhase = .idle
        }
    }
    /// Groq is the default when configured; the user's selection remains active until changed.
    public var selectedSource: LookupSource
    public let contextCatalog: ProfessionalContextCatalog
    public var selectedLanguage: TargetLanguage {
        didSet {
            guard selectedLanguage == .vietnamese || selectedLanguage == .simpleEnglish else {
                selectedLanguage = .vietnamese
                return
            }
            preferences.set(selectedLanguage.code, forKey: Self.languageKey)
        }
    }
    public private(set) var availableLanguages: [TargetLanguage] = [.vietnamese, .simpleEnglish]
    public private(set) var phase: LookupPhase = .idle
    public private(set) var result: LookupResult?
    public private(set) var completedLookup: CompletedLookup?
    public private(set) var vietnameseResult: LookupResult?
    public private(set) var vietnamesePhase: LookupPhase = .idle

    @ObservationIgnored private let explainer: any LocalExplaining
    @ObservationIgnored private let translator: (any LocalTranslating)?
    @ObservationIgnored private let groq: (any GroqLookupProviding)?
    @ObservationIgnored private let groqConfiguration: GroqConfiguration?
    @ObservationIgnored private let history: LookupHistory?
    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private var requestGeneration = 0
    @ObservationIgnored private var completedSource: LookupSource?
    private static let languageKey = "lookup.targetLanguage"

    public init(explainer: any LocalExplaining, translator: (any LocalTranslating)? = nil, groq: (any GroqLookupProviding)? = nil, groqConfiguration: GroqConfiguration? = nil, history: LookupHistory? = nil, preferences: UserDefaults = .standard, contextCatalog: ProfessionalContextCatalog? = nil) {
        self.explainer = explainer
        self.translator = translator
        self.groq = groq
        self.groqConfiguration = groqConfiguration
        self.history = history
        self.preferences = preferences
        self.contextCatalog = contextCatalog ?? ProfessionalContextCatalog(defaults: preferences)
        selectedSource = groq == nil ? .local : .groq
        let saved = preferences.string(forKey: Self.languageKey)
        selectedLanguage = saved == TargetLanguage.simpleEnglish.code ? .simpleEnglish : .vietnamese
    }

    public func loadAvailableLanguages() async {
        availableLanguages = [.vietnamese, .simpleEnglish]
    }

    public func submit() async {
        guard phase != .loading else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            phase = .error("Enter an English word or short phrase to look up.")
            return
        }
        guard Self.isShortPhrase(trimmed) else {
            phase = .error("Select an English word or short phrase in the text before looking it up.")
            return
        }
        phase = .loading
        requestGeneration += 1
        let generation = requestGeneration
        result = nil
        completedLookup = nil
        vietnameseResult = nil
        vietnamesePhase = .idle
        completedSource = nil
        let source = selectedSource
        let request = LookupRequest(text: trimmed, context: contextCatalog.selectedContext)
        let target = selectedLanguage
        do {
            let resolved: LookupResult
            if source == .groq {
                guard let groq, let groqConfiguration else { throw LookupError.groqUnavailable }
                let apiKey = try groqConfiguration.keyForLookup()
                resolved = try await groq.lookup(request, to: target, apiKey: apiKey)
            } else if target.isSimpleEnglish {
                resolved = try await explainer.explain(request)
            } else if let translator {
                resolved = try await translator.translate(request, to: target)
            } else {
                throw LookupError.translationUnavailable
            }
            guard generation == requestGeneration else { return }
            result = resolved
            phase = .result
            completedLookup = CompletedLookup(request: request, targetLanguage: target, result: resolved)
            completedSource = source
            record(request: request, target: target, result: resolved)
        } catch {
            guard generation == requestGeneration else { return }
            phase = .error(error.localizedDescription)
        }
    }

    /// Loads a Vietnamese companion result only when the English result is expanded.
    public func loadVietnameseResult() async {
        guard let completedLookup, completedLookup.targetLanguage == .simpleEnglish,
              let source = completedSource,
              vietnamesePhase != .loading, vietnamesePhase != .result else { return }
        let generation = requestGeneration
        vietnamesePhase = .loading
        do {
            let resolved: LookupResult
            if source == .groq {
                guard let groq, let groqConfiguration else { throw LookupError.groqUnavailable }
                let apiKey = try groqConfiguration.keyForLookup()
                resolved = try await groq.lookup(completedLookup.request, to: .vietnamese, apiKey: apiKey)
            } else if let translator {
                resolved = try await translator.translate(completedLookup.request, to: .vietnamese)
            } else {
                throw LookupError.translationUnavailable
            }
            guard generation == requestGeneration else { return }
            vietnameseResult = resolved
            vietnamesePhase = .result
        } catch {
            guard generation == requestGeneration else { return }
            vietnamesePhase = .error(error.localizedDescription)
        }
    }

    /// Resolves a temporary Vietnamese meaning without replacing or recording
    /// the completed lookup currently shown in the panel.
    public func quickMeaning(for text: String) async throws -> LookupResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isClearShortPhrase(trimmed) else {
            throw LookupError.invalidPhrase
        }

        let request = LookupRequest(text: trimmed, context: contextCatalog.selectedContext)
        let source = completedSource ?? selectedSource
        if source == .groq {
            guard let groq, let groqConfiguration else { throw LookupError.groqUnavailable }
            let apiKey = try groqConfiguration.keyForLookup()
            return try await groq.lookup(request, to: .vietnamese, apiKey: apiKey)
        }
        guard let translator else { throw LookupError.translationUnavailable }
        return try await translator.translate(request, to: .vietnamese)
    }

    public static func isShortPhrase(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 32,
              !trimmed.contains(where: \.isNewline) else { return false }
        return (1...4).contains(trimmed.split(whereSeparator: \.isWhitespace).count)
    }

    public static func isClearShortPhrase(_ text: String) -> Bool {
        guard isShortPhrase(text) else { return false }
        return text.split(whereSeparator: \.isWhitespace).allSatisfy { word in
            word.unicodeScalars.allSatisfy {
                CharacterSet.letters.contains($0) || $0 == "'" || $0 == "-"
            }
        }
    }

    public func submit(selectedPhrase: String) async {
        guard let choice = SelectedLookupText(source: text, phrase: selectedPhrase),
              Self.isShortPhrase(choice.phrase) else {
            phase = .error("Select an English word or short phrase in the text before looking it up.")
            return
        }
        text = choice.phrase
        await submit()
    }

    /// Repeats a completed lookup after its professional context changes.
    public func refreshForSelectedContext() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if phase == .loading {
            requestGeneration += 1
            phase = .idle
            await submit()
            return
        }
        guard completedLookup?.request.text == trimmed else { return }
        await submit()
    }

    private func record(request: LookupRequest, target: TargetLanguage, result: LookupResult) {
        // Saving history is optional and must not replace a successful result.
        try? history?.record(text: request.text, targetLanguage: target, context: request.context, result: result)
    }
}

private enum LookupError: LocalizedError {
    case invalidPhrase
    case translationUnavailable
    case groqUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidPhrase:
            "Select an English word or short phrase in the text before looking it up."
        case .translationUnavailable:
            "Local translation is unavailable on this Mac. Your lookup was not sent to another provider."
        case .groqUnavailable:
            "Groq is not configured for this app."
        }
    }
}
