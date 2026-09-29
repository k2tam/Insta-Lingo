import Foundation
@preconcurrency import Translation
import LookupCore

@MainActor
struct LocalAppleTranslator: LocalTranslating {
    private let availability = LanguageAvailability()
    private let english = Locale.Language(identifier: "en")
    private let explainer: any LocalExplaining

    init(explainer: (any LocalExplaining)? = nil) {
        self.explainer = explainer ?? LocalFoundationExplainer()
    }

    func supportedTargetLanguages() async -> [TargetLanguage] {
        await availability.supportedLanguages
            .map { TargetLanguage(code: $0.minimalIdentifier) }
            .filter { !$0.isSimpleEnglish }
    }

    func translate(_ request: LookupRequest, to target: TargetLanguage) async throws -> LookupResult {
        let targetLanguage = Locale.Language(identifier: target.code)
        let status = await availability.status(from: english, to: targetLanguage)
        switch status {
        case .unsupported:
            throw LocalTranslationAvailabilityError.unsupported(target.displayName)
        case .supported:
            throw LocalTranslationAvailabilityError.notInstalled(target.displayName)
        case .installed:
            break
        @unknown default:
            throw LocalTranslationAvailabilityError.unsupported(target.displayName)
        }

        let explanation = try await explainer.explain(request)
        let englishMeaning = explanation.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        let englishExample = explanation.example.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !englishMeaning.isEmpty, !englishExample.isEmpty else {
            throw LocalTranslationError.invalidExplanation
        }

        let session = TranslationSession(installedSource: english, target: targetLanguage)
        let meaning: String
        let example: String
        do {
            let responses = try await session.translations(from: [
                .init(sourceText: englishMeaning, clientIdentifier: "meaning"),
                .init(sourceText: englishExample, clientIdentifier: "example"),
            ])
            let byID = Dictionary(responses.compactMap { response in
                response.clientIdentifier.map { ($0, response.targetText) }
            }, uniquingKeysWith: { first, _ in first })
            meaning = (byID["meaning"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            example = (byID["example"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw LocalTranslationError.translationFailed
        }
        guard !meaning.isEmpty, !example.isEmpty else { throw LocalTranslationError.emptyResponse }
        return LookupResult(meaning: meaning, example: example, detail: "Translated on this Mac from English to \(target.displayName).")
    }
}

private enum LocalTranslationAvailabilityError: LocalizedError, LocalLookupUnavailable {
    case unsupported(String)
    case notInstalled(String)

    var errorDescription: String? {
        switch self {
        case .unsupported(let language):
            "English to \(language) is not supported by Apple Translation on this Mac. Your lookup was not sent to another provider."
        case .notInstalled(let language):
            "English to \(language) is supported, but its language files are not installed. Install them on this Mac, then try again."
        }
    }
}

private enum LocalTranslationError: LocalizedError {
    case invalidExplanation
    case translationFailed
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidExplanation:
            "The on-device model did not return a usable explanation and example. Try again."
        case .translationFailed:
            "Apple Translation could not translate the explanation and example. Try again."
        case .emptyResponse:
            "Apple Translation did not return a usable explanation and example. Try again."
        }
    }
}
