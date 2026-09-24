import AppKit
import Carbon
import LookupCore
import Observation

@MainActor @Observable
final class GlobalHotkeyManager {
    static let storageKey = "globalHotkeys.assignments"

    private(set) var assignments: HotkeyAssignments
    private(set) var registrationErrors: [HotkeyAction: OSStatus] = [:]
    var onAction: (@MainActor (HotkeyAction) -> Void)?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var references: [HotkeyAction: EventHotKeyRef] = [:]
    @ObservationIgnored private var eventHandler: EventHandlerRef?
    @ObservationIgnored private var isRecording = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(HotkeyAssignments.self, from: data) {
            assignments = decoded
        } else {
            assignments = .defaults
        }

        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetApplicationEventTarget(), globalHotkeyEventHandler, 1, &type, pointer, &eventHandler)
        guard status == noErr else {
            for action in HotkeyAction.allCases { registrationErrors[action] = status }
            return
        }
        for action in HotkeyAction.allCases { registerStored(action) }
    }

    deinit {
        for reference in references.values { UnregisterEventHotKey(reference) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    /// Retain the previous working shortcut if registration is rejected by macOS.
    @discardableResult
    func assign(_ shortcut: HotkeyShortcut, to action: HotkeyAction) -> Bool {
        guard shortcut.isValid else {
            registrationErrors[action] = OSStatus(eventHotKeyInvalidErr)
            return false
        }
        var proposed = assignments
        proposed[action] = shortcut
        guard proposed.conflictingAction(for: action) == nil else {
            registrationErrors[action] = OSStatus(eventHotKeyExistsErr)
            return false
        }
        let previous = assignments[action]
        if previous == shortcut, references[action] != nil {
            registrationErrors[action] = nil
            return true
        }
        if let reference = references.removeValue(forKey: action) { UnregisterEventHotKey(reference) }
        let status = register(shortcut, for: action)
        guard status == noErr else {
            registrationErrors[action] = status
            _ = register(previous, for: action)
            return false
        }
        assignments = proposed
        defaults.set(try? JSONEncoder().encode(assignments), forKey: Self.storageKey)
        registrationErrors[action] = nil
        return true
    }

    func suspendForRecording() {
        guard !isRecording else { return }
        isRecording = true
        for reference in references.values { UnregisterEventHotKey(reference) }
        references.removeAll()
    }

    func resumeAfterRecording() {
        guard isRecording else { return }
        isRecording = false
        for action in HotkeyAction.allCases {
            registrationErrors[action] = nil
            registerStored(action)
        }
    }

    fileprivate func dispatch(id: UInt32) {
        guard let action = HotkeyAction.allCases.first(where: { UInt32($0.index) == id }),
              references[action] != nil else { return }
        onAction?(action)
    }

    private func registerStored(_ action: HotkeyAction) {
        let shortcut = assignments[action]
        guard shortcut.isValid, assignments.conflictingAction(for: action) == nil else {
            registrationErrors[action] = OSStatus(eventHotKeyInvalidErr)
            return
        }
        let status = register(shortcut, for: action)
        if status != noErr { registrationErrors[action] = status }
    }

    private func register(_ shortcut: HotkeyShortcut, for action: HotkeyAction) -> OSStatus {
        var reference: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x5441474C), id: UInt32(action.index)) // TAGL
        let status = RegisterEventHotKey(UInt32(shortcut.keyCode), shortcut.carbonModifiers, id, GetApplicationEventTarget(), 0, &reference)
        if status == noErr, let reference { references[action] = reference }
        return status
    }
}

private let globalHotkeyEventHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var id = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
    guard status == noErr, id.signature == OSType(0x5441474C) else { return OSStatus(eventNotHandledErr) }
    let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in manager.dispatch(id: id.id) }
    return noErr
}

private extension HotkeyAction {
    var index: Int { HotkeyAction.allCases.firstIndex(of: self)! + 1 }
}

private extension HotkeyShortcut {
    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}
