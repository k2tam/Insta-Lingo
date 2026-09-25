import AppKit
import SwiftUI
import LookupCore

/// The lookup panel lives in an AppKit popover, outside a SwiftUI scene. Own
/// secondary windows here so its actions can always open or refocus them.
@MainActor
final class SupplementaryWindowsController {
    private let history: LookupHistory
    private let favorites: LookupFavorites
    private let languageSettings: UILanguageSettings
    private var historyWindow: NSWindow?
    private var favoritesWindow: NSWindow?
    private var settingsWindow: NSWindow?

    init(history: LookupHistory, favorites: LookupFavorites,
         languageSettings: UILanguageSettings) {
        self.history = history
        self.favorites = favorites
        self.languageSettings = languageSettings
    }

    func showHistory() {
        if historyWindow == nil {
            historyWindow = makeWindow(
                content: HistoryWindow(history: history, languageSettings: languageSettings)
            )
        }
        show(historyWindow, title: languageSettings.strings.history)
    }

    func showFavorites() {
        if favoritesWindow == nil {
            favoritesWindow = makeWindow(
                content: FavoritesWindow(favorites: favorites, languageSettings: languageSettings)
            )
        }
        show(favoritesWindow, title: languageSettings.strings.favorites)
    }

    func showSettings<Content: View>(content: Content) {
        if settingsWindow == nil {
            settingsWindow = makeWindow(content: content)
            settingsWindow?.contentMinSize = NSSize(width: 640, height: 420)
        }
        show(settingsWindow, title: languageSettings.strings.settingsTitle)
    }

    private func makeWindow<Content: View>(content: Content) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = NSHostingController(rootView: content)
        window.isReleasedWhenClosed = false
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.center()
        return window
    }

    private func show(_ window: NSWindow?, title: String) {
        guard let window else { return }
        window.title = title
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // A menu bar app may still be activating; order the window in front
        // even when another app is currently active.
        window.orderFrontRegardless()
    }
}
