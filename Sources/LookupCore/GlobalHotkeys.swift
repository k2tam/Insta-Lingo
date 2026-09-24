import Foundation

public enum HotkeyAction: String, CaseIterable, Codable, Identifiable, Sendable {
    case openPanel
    case selectedText
    case screenRegion

    public var id: String { rawValue }

    public var defaultShortcut: HotkeyShortcut {
        switch self {
        case .openPanel: HotkeyShortcut(keyCode: 37, modifiers: [.command, .option]) // L
        case .selectedText: HotkeyShortcut(keyCode: 1, modifiers: [.command, .option]) // S
        case .screenRegion: HotkeyShortcut(keyCode: 15, modifiers: [.command, .option]) // R
        }
    }
}

public struct HotkeyModifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let command = Self(rawValue: 1 << 0)
    public static let option = Self(rawValue: 1 << 1)
    public static let control = Self(rawValue: 1 << 2)
    public static let shift = Self(rawValue: 1 << 3)
}

public struct HotkeyShortcut: Codable, Hashable, Sendable {
    public var keyCode: UInt16
    public var modifiers: HotkeyModifiers

    public init(keyCode: UInt16, modifiers: HotkeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Require a non-text modifier so ordinary typing never opens the app.
    public var isValid: Bool {
        !modifiers.intersection([.command, .option, .control]).isEmpty
            && modifiers.subtracting([.command, .option, .control, .shift]).isEmpty
            && keyCode != 0xFF
            && keyCode != 53 // Escape cancels recording.
            && !(54...63).contains(keyCode) // Physical modifier keys.
    }
}

public struct HotkeyAssignments: Codable, Equatable, Sendable {
    private var shortcuts: [HotkeyAction: HotkeyShortcut]

    public static var defaults: Self {
        Self(shortcuts: Dictionary(uniqueKeysWithValues: HotkeyAction.allCases.map { ($0, $0.defaultShortcut) }))
    }

    public subscript(action: HotkeyAction) -> HotkeyShortcut {
        get { shortcuts[action] ?? action.defaultShortcut }
        set { shortcuts[action] = newValue }
    }

    public func conflictingAction(for action: HotkeyAction) -> HotkeyAction? {
        HotkeyAction.allCases.first { $0 != action && self[$0] == self[action] }
    }
}
