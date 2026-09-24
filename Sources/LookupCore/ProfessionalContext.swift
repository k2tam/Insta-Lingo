import Foundation
import Observation

/// A field that can change the meaning and example in a lookup.
public struct ProfessionalContext: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String

    public static let general = Self(
        id: "general",
        name: "General",
        description: "Everyday English usage without a specialized field."
    )
    public static let softwareDevelopment = Self(
        id: "software-development",
        name: "Software Development",
        description: "Software design, programming, and engineering terminology."
    )
    public static let swiftIOS = Self(
        id: "swift-ios",
        name: "Swift/iOS",
        description: "Swift language and Apple app development terminology."
    )

    public static let builtIns = [general, softwareDevelopment, swiftIOS]

    public init(id: String, name: String, description: String) {
        self.id = id
        self.name = name
        self.description = description
    }
}

/// Persists user-created fields and the field used for the next lookup.
@MainActor @Observable
public final class ProfessionalContextCatalog {
    public private(set) var contexts: [ProfessionalContext]
    public private(set) var selectedContext: ProfessionalContext

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let storageKey: String

    public init(defaults: UserDefaults = .standard, storageKey: String = "professionalContexts") {
        self.defaults = defaults
        self.storageKey = storageKey

        let stored: [ProfessionalContext]
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ProfessionalContext].self, from: data) {
            stored = decoded.filter { context in
                context.id.hasPrefix("custom-") &&
                !context.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !context.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        } else {
            stored = []
        }

        var seen = Set(ProfessionalContext.builtIns.map(\.id))
        let custom = stored.filter { seen.insert($0.id).inserted }
        let allContexts = ProfessionalContext.builtIns + custom
        contexts = allContexts
        let selectedID = defaults.string(forKey: "\(storageKey).selectedID")
        selectedContext = allContexts.first { $0.id == selectedID } ?? .general
    }

    @discardableResult
    public func select(id: String) -> Bool {
        guard let context = contexts.first(where: { $0.id == id }) else { return false }
        selectedContext = context
        defaults.set(id, forKey: "\(storageKey).selectedID")
        return true
    }

    @discardableResult
    public func addCustom(name: String, description: String) -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !cleanDescription.isEmpty,
              !contexts.contains(where: { $0.name.localizedCaseInsensitiveCompare(cleanName) == .orderedSame })
        else { return false }

        let context = ProfessionalContext(
            id: "custom-\(UUID().uuidString)",
            name: cleanName,
            description: cleanDescription
        )
        contexts.append(context)
        persistCustomContexts()
        return select(id: context.id)
    }

    private func persistCustomContexts() {
        let custom = contexts.filter { $0.id.hasPrefix("custom-") }
        guard let data = try? JSONEncoder().encode(custom) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
