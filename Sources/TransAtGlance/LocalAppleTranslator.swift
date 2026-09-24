import Foundation
@preconcurrency import Translation
import LookupCore

@MainActor
struct LocalAppleTranslator: LocalTranslating {
    private let availability = LanguageAvailability()
    private let english = Locale.Language(identifier: "en")
    private let explainer: any LocalExplaining

    init(explainer: any LocalExplaining = LocalFoundationExplainer()) {
        self.explainer = explainer
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

        let session = TranslationSession(installedSource: english, target: targetLanguage)
        let response = try await session.translate(request.text)
        let meaning = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !meaning.isEmpty else { throw LocalTranslationError.emptyResponse }
        var example = ""
        if let explanation = try? await explainer.explain(request), !explanation.example.isEmpty,
           let translated = try? await session.translate(explanation.example) {
            example = translated.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
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
    case emptyResponse

    var errorDescription: String? {
        "Apple Translation did not return a usable translation. Try again."
    }
}
