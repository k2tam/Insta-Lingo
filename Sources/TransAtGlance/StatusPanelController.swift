import AppKit
import SwiftUI

/// Owns the menu bar item so global shortcuts can open the same anchored panel
/// that a click on the icon opens. Transient behavior closes it on focus loss.
@MainActor
final class StatusPanelController: NSObject {
    private let item: NSStatusItem
    private let popover = NSPopover()

    override init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        item.button?.image = NSImage(systemSymbolName: "text.book.closed", accessibilityDescription: "TransAtGlance")
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

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        present()
    }

    /// The region overlay leaves another app active. Wait for AppKit to finish
    /// activating us before presenting a transient popover, or it can close
    /// immediately as an outside-app interaction.
    func showAfterRegionSelection() async {
        NSApp.activate(ignoringOtherApps: true)
        for _ in 0..<50 where !NSApp.isActive {
            try? await Task.sleep(for: .milliseconds(20))
        }
        present()
    }

    private func present() {
        guard let button = item.button, popover.contentViewController != nil else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func hide() { popover.performClose(nil) }

    @objc private func togglePanel() {
        if popover.isShown { hide() } else { show() }
    }
}
