import AppKit
import ApplicationServices
import LookupCore

/// Remembers the document application while the menu bar panel takes focus.
/// The reader never searches other applications for text.
@MainActor
final class PreviousAppTracker {
    private(set) var processIdentifier: pid_t?
    private var activationObserver: NSObjectProtocol?

    init() {
        record(NSWorkspace.shared.frontmostApplication)
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let pid = application.processIdentifier
            Task { @MainActor [weak self] in self?.record(pid: pid) }
        }
    }

    private func record(_ application: NSRunningApplication?) {
        guard let application else { return }
        record(pid: application.processIdentifier)
    }

    private func record(pid: pid_t) {
        guard pid != ProcessInfo.processInfo.processIdentifier else { return }
        processIdentifier = pid
    }
}

/// Requests Accessibility only when the person presses "Look up selection".
/// AXSelectedText is the sole text attribute read from the focused element.
@MainActor
final class AccessibilitySelectedTextReader: SelectedTextReading {
    private let previousApp: PreviousAppTracker
    private var permissionPendingPID: pid_t?

    init(previousApp: PreviousAppTracker) {
        self.previousApp = previousApp
    }

    func readSelectedText() async -> SelectionReadResult {
        let targetPID = permissionPendingPID ?? previousApp.processIdentifier
        // The AX prompt option's constant is imported as mutable global state
        // under Swift 6. Use its documented dictionary key spelling.
        guard AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) else {
            permissionPendingPID = targetPID
            return .permissionRequired
        }
        permissionPendingPID = nil
        guard let pid = targetPID else { return .unavailable }

        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 1)
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            return .unavailable
        }
        let focusedElement = focusedValue as! AXUIElement
        AXUIElementSetMessagingTimeout(focusedElement, 1)

        var selectedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &selectedValue) == .success,
              let selectedText = selectedValue as? String,
              !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .unavailable
        }
        return .selected(selectedText)
    }
}
