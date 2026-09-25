import AppKit
import ApplicationServices
import LookupCore
import OSLog

private let selectionDebugLogger = Logger(subsystem: "com.k2tam.InstaLingo", category: "DEBUG-hotkey-7f3a")

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
        let targetBundleID = targetPID.flatMap { NSRunningApplication(processIdentifier: $0)?.bundleIdentifier } ?? "none"
        selectionDebugLogger.notice("[DEBUG-hotkey-7f3a] read target=\(targetBundleID, privacy: .public)")
        // The AX prompt option's constant is imported as mutable global state
        // under Swift 6. Use its documented dictionary key spelling.
        guard AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) else {
            selectionDebugLogger.notice("[DEBUG-hotkey-7f3a] accessibility permission required")
            permissionPendingPID = targetPID
            return .permissionRequired
        }
        permissionPendingPID = nil
        guard let pid = targetPID else { return .unavailable }

        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 1)
        var focusedValue: CFTypeRef?
        let focusedError = AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &focusedValue)
        guard focusedError == .success,
              let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            selectionDebugLogger.notice("[DEBUG-hotkey-7f3a] focused element unavailable error=\(focusedError.rawValue)")
            return .unavailable
        }
        let focusedElement = focusedValue as! AXUIElement
        AXUIElementSetMessagingTimeout(focusedElement, 1)

        var attributeNames: CFArray?
        let namesError = AXUIElementCopyAttributeNames(focusedElement, &attributeNames)
        let names = attributeNames as? [String] ?? []
        let hasMarkerRange = names.contains("AXSelectedTextMarkerRange")
        selectionDebugLogger.notice(
            "[DEBUG-hotkey-7f3a] focused attributes error=\(namesError.rawValue) text=\(names.contains(kAXSelectedTextAttribute)) range=\(names.contains(kAXSelectedTextRangeAttribute)) markerRange=\(hasMarkerRange)"
        )

        var selectedValue: CFTypeRef?
        let selectedError = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &selectedValue)
        if selectedError == .success,
           let selectedText = selectedValue as? String,
           !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            selectionDebugLogger.notice("[DEBUG-hotkey-7f3a] selected text available")
            return .selected(selectedText)
        }

        // Web content such as Safari pages exposes its selection as a text
        // marker range rather than the editable-text AXSelectedText value.
        var markerRangeValue: CFTypeRef?
        let markerRangeError = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextMarkerRangeAttribute as CFString,
            &markerRangeValue
        )
        if markerRangeError == .success, let markerRangeValue {
            var markerTextValue: CFTypeRef?
            let markerTextError = AXUIElementCopyParameterizedAttributeValue(
                focusedElement,
                kAXStringForTextMarkerRangeParameterizedAttribute as CFString,
                markerRangeValue,
                &markerTextValue
            )
            if markerTextError == .success,
               let markerText = markerTextValue as? String,
               !markerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                selectionDebugLogger.notice("[DEBUG-hotkey-7f3a] marker text available")
                return .selected(markerText)
            }
            selectionDebugLogger.notice("[DEBUG-hotkey-7f3a] marker text unavailable error=\(markerTextError.rawValue)")
        }

        selectionDebugLogger.notice(
            "[DEBUG-hotkey-7f3a] selected text unavailable textError=\(selectedError.rawValue) markerError=\(markerRangeError.rawValue)"
        )
        return .unavailable
    }
}
