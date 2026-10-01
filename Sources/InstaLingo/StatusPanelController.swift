import AppKit
import SwiftUI
import os

private let ocrDebugLogger = Logger(subsystem: "com.k2tam.InstaLingo", category: "DEBUG-ocr-9c2e")

/// Owns the menu bar item so global shortcuts can open the same anchored panel
/// that a click on the icon opens. Transient behavior closes it on focus loss.
@MainActor
final class StatusPanelController: NSObject {
    private let item: NSStatusItem
    private let popover = NSPopover()
    var onPresent: ((Bool) -> Void)?
    var onOpen: (() -> Void)?

    override init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        item.button?.image = NSImage(systemSymbolName: "text.book.closed", accessibilityDescription: "Insta Lingo")
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        popover.behavior = .transient
        popover.animates = true
    }

    func setContent(_ content: AnyView) {
        let hosting = NSHostingController(rootView: content)
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
    }

    func show(focusInput: Bool = true) {
        Task { await showAfterActivation(focusInput: focusInput) }
    }

    func showAfterRegionSelection() async {
        await showAfterActivation(focusInput: false)
    }

    /// Global shortcuts and the region overlay leave another app active. Wait
    /// for AppKit to finish activating us before presenting a transient
    /// popover, or it closes immediately as an outside-app interaction.
    func showAfterActivation(focusInput: Bool) async {
        ocrDebugLogger.notice("[DEBUG-ocr-9c2e] activate start active=\(NSApp.isActive, privacy: .public) t=\(Date().timeIntervalSince1970, privacy: .public)")
        NSApp.activate(ignoringOtherApps: true)
        for _ in 0..<50 where !NSApp.isActive {
            try? await Task.sleep(for: .milliseconds(20))
        }
        ocrDebugLogger.notice("[DEBUG-ocr-9c2e] activate done active=\(NSApp.isActive, privacy: .public) t=\(Date().timeIntervalSince1970, privacy: .public)")
        present(focusInput: focusInput)
    }

    private func present(focusInput: Bool) {
        guard let button = item.button, popover.contentViewController != nil else { return }
        ocrDebugLogger.notice("[DEBUG-ocr-9c2e] present shown=\(self.popover.isShown, privacy: .public) t=\(Date().timeIntervalSince1970, privacy: .public)")
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            onPresent?(focusInput)
        }
    }

    func hide() {
        ocrDebugLogger.notice("[DEBUG-ocr-9c2e] hide t=\(Date().timeIntervalSince1970, privacy: .public)")
        popover.performClose(nil)
    }

    @objc private func togglePanel() {
        if popover.isShown { hide() } else {
            onOpen?()
            show()
        }
    }
}
