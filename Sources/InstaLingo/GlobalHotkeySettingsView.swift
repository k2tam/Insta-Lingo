import AppKit
import Carbon
import SwiftUI
import LookupCore

struct GlobalHotkeySettingsView: View {
    @Bindable var manager: GlobalHotkeyManager
    let strings: UIStrings
    @State private var recordingAction: HotkeyAction?
    @State private var keyMonitor: Any?
    @State private var invalidAction: HotkeyAction?

    var body: some View {
        Form {
            Section {
                ForEach(HotkeyAction.allCases) { action in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 12) {
                            Text(strings.hotkeyActionName(action))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(recordingAction == action ? "…" : manager.assignments[action].displayName)
                                .font(.system(.body, design: .monospaced))
                                .frame(minWidth: 72, alignment: .trailing)
                            Button(recordingAction == action ? strings.cancel : strings.hotkeyChange) {
                                if recordingAction == action {
                                    stopRecording()
                                } else {
                                    beginRecording(action)
                                }
                            }
                            .accessibilityLabel("\(recordingAction == action ? strings.cancel : strings.hotkeyChange): \(strings.hotkeyActionName(action))")
                        }

                        if recordingAction == action {
                            Text(strings.hotkeyRecording)
                                .foregroundStyle(.secondary)
                        } else if invalidAction == action {
                            Text(strings.hotkeyInvalid)
                                .foregroundStyle(.red)
                        } else if let status = manager.registrationErrors[action] {
                            Text(status == OSStatus(eventHotKeyExistsErr) ? strings.hotkeyConflict : strings.hotkeyRegistrationFailed)
                                .foregroundStyle(.red)
                        }
                    }
                }
            } header: {
                Text(strings.hotkeysTitle)
            } footer: {
                Text(strings.hotkeyCancelHint)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onDisappear { stopRecording() }
    }

    private func beginRecording(_ action: HotkeyAction) {
        stopRecording()
        invalidAction = nil
        recordingAction = action
        manager.suspendForRecording()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape
                stopRecording()
                return nil
            }
            let shortcut = HotkeyShortcut(event: event)
            guard shortcut.isValid else {
                invalidAction = action
                return nil
            }
            invalidAction = nil
            stopRecording()
            _ = manager.assign(shortcut, to: action)
            return nil
        }
    }

    private func stopRecording() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        recordingAction = nil
        manager.resumeAfterRecording()
    }
}

extension HotkeyShortcut {
    init(event: NSEvent) {
        var modifiers: HotkeyModifiers = []
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
        if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        self.init(keyCode: event.keyCode, modifiers: modifiers)
    }

    var displayName: String {
        var name = ""
        if modifiers.contains(.control) { name += "⌃" }
        if modifiers.contains(.option) { name += "⌥" }
        if modifiers.contains(.shift) { name += "⇧" }
        if modifiers.contains(.command) { name += "⌘" }
        return name + Self.keyNames[keyCode, default: "Key \(keyCode)"]
    }

    static let keyNames: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B",
        12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P",
        37: "L", 38: "J", 40: "K", 45: "N", 46: "M", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5",
        22: "6", 26: "7", 28: "8", 25: "9", 29: "0", 49: "Space", 36: "Return", 48: "Tab",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
}
