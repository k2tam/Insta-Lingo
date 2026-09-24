import Foundation
import Observation

/// A saved result is a snapshot, independent of lookup history and later edits
/// to the selected language or professional context.
public struct LookupFavorite: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let savedAt: Date
    public let text: String
    public let targetLanguageCode: String
    public let context: ProfessionalContext
    public let meaning: String
    public let example: String
    public let detail: String

    public var result: LookupResult {
        LookupResult(meaning: meaning, example: example, detail: detail)
    }

    public init(id: UUID = UUID(), savedAt: Date = Date(), text: String,
                targetLanguage: TargetLanguage, context: ProfessionalContext,
                result: LookupResult) {
        self.id = id
        self.savedAt = savedAt
        self.text = text
        self.targetLanguageCode = targetLanguage.code
        self.context = context
        self.meaning = result.meaning
        self.example = result.example
        self.detail = result.detail
    }
}

@MainActor @Observable
public final class LookupFavorites {
    public private(set) var entries: [LookupFavorite]
    public private(set) var persistenceError: String?

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let fileManager: FileManager

    public init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? fileManager.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask)[0]
            .appendingPathComponent("TransAtGlance", isDirectory: true)
            .appendingPathComponent("favorites.json")
        do {
            if fileManager.fileExists(atPath: self.fileURL.path) {
                entries = try JSONDecoder().decode([LookupFavorite].self,
                                                   from: Data(contentsOf: self.fileURL))
            } else {
                entries = []
            }
        } catch {
            entries = []
            persistenceError = error.localizedDescription
        }
    }

    public func contains(text: String, targetLanguage: TargetLanguage,
                         context: ProfessionalContext) -> Bool {
        entries.contains { matches($0, text: text, targetLanguage: targetLanguage, context: context) }
    }

    /// Saving the same word, target language and context updates that favorite
    /// with the current result. Other languages and contexts remain separate.
    public func save(text: String, targetLanguage: TargetLanguage,
                     context: ProfessionalContext, result: LookupResult) throws {
        let updated = [LookupFavorite(text: text, targetLanguage: targetLanguage,
                                      context: context, result: result)]
            + entries.filter { !matches($0, text: text, targetLanguage: targetLanguage, context: context) }
        try persist(updated)
        entries = updated
    }

    public func remove(id: UUID) throws {
        let updated = entries.filter { $0.id != id }
        try persist(updated)
        entries = updated
    }

    public func search(_ query: String) -> [LookupFavorite] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return entries }
        return entries.filter { entry in
            [entry.text, entry.meaning, entry.example, entry.detail,
             entry.context.name, entry.targetLanguageCode]
                .contains { $0.localizedStandardContains(term) }
        }
    }

    private func matches(_ entry: LookupFavorite, text: String,
                         targetLanguage: TargetLanguage, context: ProfessionalContext) -> Bool {
        entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveCompare(text.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        && entry.targetLanguageCode == targetLanguage.code
        && entry.context.id == context.id
    }

    private func persist(_ entries: [LookupFavorite]) throws {
        do {
            try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
            try JSONEncoder().encode(entries).write(to: fileURL, options: .atomic)
            persistenceError = nil
        } catch {
            persistenceError = error.localizedDescription
            throw error
        }
    }
}
