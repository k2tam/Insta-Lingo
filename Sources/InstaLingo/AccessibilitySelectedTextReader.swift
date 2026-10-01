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
/// Only selection attributes are read: from the focused element, or from its
/// ancestors when the selection is owned by an enclosing text or web area.
@MainActor
final class AccessibilitySelectedTextReader: SelectedTextReading {
    private static let messagingTimeout: Float = 1
    private static let maxAncestorDepth = 8

    private let previousApp: PreviousAppTracker
    private var permissionPendingPID: pid_t?
    private var manualAccessibilityPIDs: Set<pid_t> = []

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

        guard let focusedElement = focusedElement(fallbackPID: targetPID) else { return .unavailable }

        var element: AXUIElement? = focusedElement
        var depth = 0
        while let current = element, depth <= Self.maxAncestorDepth {
            let role = stringAttribute(kAXRoleAttribute, of: current) ?? "unknown"
            if let text = selectedText(in: current, role: role) {
                return .selected(text)
            }
            if role == kAXWindowRole || role == kAXApplicationRole { break }
            element = elementAttribute(kAXParentAttribute, of: current)
            depth += 1
        }

        selectionDebugLogger.notice("[DEBUG-hotkey-7f3a] selected text unavailable depth=\(depth)")
        return .unavailable
    }

    /// Prefers the system-wide focus, which stays correct when the activation
    /// notification has not reached `PreviousAppTracker` yet.
    private func focusedElement(fallbackPID: pid_t?) -> AXUIElement? {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, Self.messagingTimeout)
        if let element = elementAttribute(kAXFocusedUIElementAttribute, of: systemWide) {
            var pid: pid_t = 0
            if AXUIElementGetPid(element, &pid) == .success, pid != ownPID {
                enableManualAccessibility(pid: pid)
                selectionDebugLogger.notice("[DEBUG-hotkey-7f3a] focus from system-wide element")
                return element
            }
        }

        guard let pid = fallbackPID else { return nil }
        enableManualAccessibility(pid: pid)
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, Self.messagingTimeout)
        var focusedValue: CFTypeRef?
        let focusedError = AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &focusedValue)
        guard focusedError == .success,
              let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            selectionDebugLogger.notice("[DEBUG-hotkey-7f3a] focused element unavailable error=\(focusedError.rawValue)")
            return nil
        }
        return (focusedValue as! AXUIElement)
    }

    /// Chromium and Electron apps expose their accessibility tree only after
    /// a client asks for it; the first reads may fail until it is built.
    private func enableManualAccessibility(pid: pid_t) {
        guard !manualAccessibilityPIDs.contains(pid) else { return }
        manualAccessibilityPIDs.insert(pid)
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, Self.messagingTimeout)
        _ = AXUIElementSetAttributeValue(application, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }

    private func selectedText(in element: AXUIElement, role: String) -> String? {
        AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)

        if let text = nonEmpty(stringAttribute(kAXSelectedTextAttribute, of: element)) {
            selectionDebugLogger.notice("[DEBUG-hotkey-7f3a] selected text via AXSelectedText role=\(role, privacy: .public)")
            return text
        }

        // Some AppKit and Catalyst views report the range but leave
        // AXSelectedText empty.
        var rangeValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
           let rangeValue,
           CFGetTypeID(rangeValue) == AXValueGetTypeID() {
            var range = CFRange()
            if AXValueGetValue(rangeValue as! AXValue, .cfRange, &range), range.length > 0 {
                var rangeText: CFTypeRef?
                if AXUIElementCopyParameterizedAttributeValue(
                    element,
                    kAXStringForRangeParameterizedAttribute as CFString,
                    rangeValue,
                    &rangeText
                ) == .success, let text = nonEmpty(rangeText as? String) {
                    selectionDebugLogger.notice("[DEBUG-hotkey-7f3a] selected text via range role=\(role, privacy: .public)")
                    return text
                }
            }
        }

        // Web content such as Safari pages exposes its selection as a text
        // marker range, usually on the enclosing AXWebArea.
        var markerRangeValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextMarkerRangeAttribute as CFString,
            &markerRangeValue
        ) == .success, let markerRangeValue {
            var markerTextValue: CFTypeRef?
            if AXUIElementCopyParameterizedAttributeValue(
                element,
                kAXStringForTextMarkerRangeParameterizedAttribute as CFString,
                markerRangeValue,
                &markerTextValue
            ) == .success, let text = nonEmpty(markerTextValue as? String) {
                selectionDebugLogger.notice("[DEBUG-hotkey-7f3a] selected text via marker range role=\(role, privacy: .public)")
                return text
            }
        }
        return nil
    }

    private func nonEmpty(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    private func stringAttribute(_ attribute: String, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func elementAttribute(_ attribute: String, of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
}

/// Last resort for apps that keep their selection out of Accessibility
/// (WhatsApp message bubbles): sends ⌘C to the frontmost app, reads the copied
/// string, then puts the person's previous clipboard contents back.
@MainActor
final class ClipboardSelectedTextReader: SelectedTextReading {
    private static let copyKeyCode: CGKeyCode = 8 // kVK_ANSI_C
    private static let pollInterval = Duration.milliseconds(20)
    private static let copyTimeout = Duration.milliseconds(400)

    func readSelectedText() async -> SelectionReadResult {
        guard AXIsProcessTrusted() else { return .permissionRequired }
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            selectionDebugLogger.notice("[DEBUG-hotkey-7f3a] clipboard fallback skipped: own app is frontmost")
            return .unavailable
        }

        let pasteboard = NSPasteboard.general
        let saved = Self.snapshot(of: pasteboard)
        let initialChangeCount = pasteboard.changeCount

        guard Self.postCopyShortcut() else { return .unavailable }

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: Self.copyTimeout)
        while pasteboard.changeCount == initialChangeCount, clock.now < deadline {
            do { try await Task.sleep(for: Self.pollInterval) } catch { break }
        }
        // Nothing was copied (no selection, or the app ignores ⌘C): the
        // clipboard is untouched, so there is nothing to restore.
        guard pasteboard.changeCount != initialChangeCount else {
            selectionDebugLogger.notice("[DEBUG-hotkey-7f3a] clipboard fallback: nothing copied")
            return .unavailable
        }

        let copied = pasteboard.string(forType: .string)
        Self.restore(saved, to: pasteboard)

        guard let copied, !copied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            selectionDebugLogger.notice("[DEBUG-hotkey-7f3a] clipboard fallback: copied value had no text")
            return .unavailable
        }
        selectionDebugLogger.notice("[DEBUG-hotkey-7f3a] selected text via clipboard fallback app=\(frontmost.bundleIdentifier ?? "unknown", privacy: .public)")
        return .selected(copied)
    }

    /// A private event source keeps the hotkey's still-held modifiers
    /// (⌥, ⇧, …) from turning ⌘C into a different shortcut.
    private static func postCopyShortcut() -> Bool {
        guard let source = CGEventSource(stateID: .privateState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: copyKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: copyKeyCode, keyDown: false) else {
            return false
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private static func snapshot(of pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            var contents: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { contents[type] = data }
            }
            return contents
        }
    }

    private static func restore(_ saved: [[NSPasteboard.PasteboardType: Data]], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !saved.isEmpty else { return }
        let items = saved.map { contents in
            let item = NSPasteboardItem()
            for (type, data) in contents { item.setData(data, forType: type) }
            return item
        }
        pasteboard.writeObjects(items)
    }
}
