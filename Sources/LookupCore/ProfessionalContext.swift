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

/// Persists available fields, their window visibility, and the field used for the next lookup.
@MainActor @Observable
public final class ProfessionalContextCatalog {
    public private(set) var contexts: [ProfessionalContext]
    public private(set) var visibleContextIDs: Set<String>
    public private(set) var selectedContext: ProfessionalContext

    public var visibleContexts: [ProfessionalContext] {
        contexts.filter { visibleContextIDs.contains($0.id) }
    }

    private struct StoredContexts: Codable {
        let contexts: [ProfessionalContext]
        let visibleIDs: [String]
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let storageKey: String

    public init(defaults: UserDefaults = .standard, storageKey: String = "professionalContexts") {
        self.defaults = defaults
        self.storageKey = storageKey

        let data = defaults.data(forKey: storageKey)
        let saved = data.flatMap { try? JSONDecoder().decode(StoredContexts.self, from: $0) }
        let allContexts: [ProfessionalContext]
        let visibleIDs: Set<String>
        if let saved {
            var seen = Set<String>()
            allContexts = saved.contexts.filter { context in
                !context.id.isEmpty &&
                !context.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !context.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                seen.insert(context.id).inserted
            }
            let validIDs = Set(allContexts.map(\.id))
            let persistedVisibleIDs = Set(saved.visibleIDs).intersection(validIDs)
            visibleIDs = persistedVisibleIDs.isEmpty ? Set(allContexts.prefix(1).map(\.id)) : persistedVisibleIDs
        } else {
            let stored = (data.flatMap { try? JSONDecoder().decode([ProfessionalContext].self, from: $0) } ?? [])
                .filter { context in
                    context.id.hasPrefix("custom-") &&
                    !context.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    !context.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            var seen = Set(ProfessionalContext.builtIns.map(\.id))
            let custom = stored.filter { seen.insert($0.id).inserted }
            allContexts = ProfessionalContext.builtIns + custom
            visibleIDs = Set(allContexts.map(\.id))
        }

        let resolvedContexts = allContexts.isEmpty ? ProfessionalContext.builtIns : allContexts
        let resolvedVisibleIDs = allContexts.isEmpty ? Set(ProfessionalContext.builtIns.map(\.id)) : visibleIDs
        let selectedID = defaults.string(forKey: "\(storageKey).selectedID")
        let resolvedSelection = resolvedContexts.first { $0.id == selectedID && resolvedVisibleIDs.contains($0.id) }
            ?? resolvedContexts.first { resolvedVisibleIDs.contains($0.id) }
            ?? resolvedContexts[0]
        contexts = resolvedContexts
        visibleContextIDs = resolvedVisibleIDs
        selectedContext = resolvedSelection
    }

    @discardableResult
    public func select(id: String) -> Bool {
        guard visibleContextIDs.contains(id),
              let context = contexts.first(where: { $0.id == id }) else { return false }
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
        visibleContextIDs.insert(context.id)
        persistContexts()
        return select(id: context.id)
    }

    @discardableResult
    public func updateCustom(id: String, name: String, description: String) -> Bool {
        guard id.hasPrefix("custom-") else { return false }
        return update(id: id, name: name, description: description)
    }

    @discardableResult
    public func update(id: String, name: String, description: String) -> Bool {
        guard let index = contexts.firstIndex(where: { $0.id == id }) else { return false }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !cleanDescription.isEmpty,
              !contexts.contains(where: {
                  $0.id != id && $0.name.localizedCaseInsensitiveCompare(cleanName) == .orderedSame
              }) else { return false }

        let updated = ProfessionalContext(id: id, name: cleanName, description: cleanDescription)
        contexts[index] = updated
        if selectedContext.id == id { selectedContext = updated }
        persistContexts()
        return true
    }

    @discardableResult
    public func removeCustom(id: String) -> Bool {
        guard id.hasPrefix("custom-") else { return false }
        return remove(id: id)
    }

    @discardableResult
    public func remove(id: String) -> Bool {
        guard contexts.count > 1,
              let index = contexts.firstIndex(where: { $0.id == id }) else { return false }
        contexts.remove(at: index)
        visibleContextIDs.remove(id)
        if visibleContextIDs.isEmpty {
            visibleContextIDs.insert(contexts[0].id)
        }
        if selectedContext.id == id { select(id: visibleContexts[0].id) }
        persistContexts()
        return true
    }

    @discardableResult
    public func setVisible(_ visible: Bool, id: String) -> Bool {
        guard contexts.contains(where: { $0.id == id }) else { return false }
        if visible {
            visibleContextIDs.insert(id)
        } else {
            guard visibleContextIDs.contains(id), visibleContextIDs.count > 1 else { return false }
            visibleContextIDs.remove(id)
            if selectedContext.id == id { select(id: visibleContexts[0].id) }
        }
        persistContexts()
        return true
    }

    private func persistContexts() {
        let stored = StoredContexts(contexts: contexts, visibleIDs: contexts.filter { visibleContextIDs.contains($0.id) }.map(\.id))
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
