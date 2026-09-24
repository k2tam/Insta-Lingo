import Foundation
import Observation

/// A completed lookup. The persisted shape contains text and result only; a
/// screen selection image cannot enter history through this interface.
public struct LookupHistoryEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let text: String
    public let targetLanguageCode: String
    public let context: ProfessionalContext
    public let meaning: String
    public let example: String
    public let detail: String

    public var result: LookupResult {
        LookupResult(meaning: meaning, example: example, detail: detail)
    }

    public init(id: UUID = UUID(), createdAt: Date = Date(), text: String,
                targetLanguage: TargetLanguage, context: ProfessionalContext,
                result: LookupResult) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.targetLanguageCode = targetLanguage.code
        self.context = context
        self.meaning = result.meaning
        self.example = result.example
        self.detail = result.detail
    }
}

@MainActor @Observable
public final class LookupHistory {
    public static let enabledKey = "lookup.historyEnabled"

    public var isEnabled: Bool {
        didSet { preferences.set(isEnabled, forKey: Self.enabledKey) }
    }
    public private(set) var entries: [LookupHistoryEntry]
    public private(set) var persistenceError: String?

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private let fileManager: FileManager

    public init(fileURL: URL? = nil, preferences: UserDefaults = .standard,
                fileManager: FileManager = .default) {
        self.preferences = preferences
        self.fileManager = fileManager
        self.fileURL = fileURL ?? fileManager.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask)[0]
            .appendingPathComponent("TransAtGlance", isDirectory: true)
            .appendingPathComponent("history.json")
        isEnabled = preferences.object(forKey: Self.enabledKey) as? Bool ?? true
        do {
            if fileManager.fileExists(atPath: self.fileURL.path) {
                entries = try JSONDecoder().decode([LookupHistoryEntry].self,
                                                   from: Data(contentsOf: self.fileURL))
            } else {
                entries = []
            }
        } catch {
            entries = []
            persistenceError = error.localizedDescription
        }
    }

    /// Call only after a provider has returned a successful result.
    public func record(text: String, targetLanguage: TargetLanguage,
                       context: ProfessionalContext, result: LookupResult) throws {
        guard isEnabled else { return }
        let entry = LookupHistoryEntry(text: text, targetLanguage: targetLanguage,
                                       context: context, result: result)
        let updated = [entry] + entries
        try save(updated)
        entries = updated
    }

    public func search(_ query: String) -> [LookupHistoryEntry] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return entries }
        return entries.filter { entry in
            [entry.text, entry.meaning, entry.example, entry.detail,
             entry.context.name, entry.targetLanguageCode]
                .contains { $0.localizedStandardContains(term) }
        }
    }

    public func clear() throws {
        try save([])
        entries = []
    }

    private func save(_ entries: [LookupHistoryEntry]) throws {
        do {
            try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
            persistenceError = nil
        } catch {
            persistenceError = error.localizedDescription
            throw error
        }
    }
}
