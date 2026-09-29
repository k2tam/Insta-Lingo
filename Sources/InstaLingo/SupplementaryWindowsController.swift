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
    private let libraryNavigation = LibraryNavigation()
    private var libraryWindow: NSWindow?
    private var settingsWindow: NSWindow?
    /// Runs a word from the library through the lookup panel again.
    var lookUpAgain: (String) -> Void = { _ in }

    init(history: LookupHistory, favorites: LookupFavorites,
         languageSettings: UILanguageSettings) {
        self.history = history
        self.favorites = favorites
        self.languageSettings = languageSettings
    }

    func showHistory() { showLibrary(tab: .all) }

    func showFavorites() { showLibrary(tab: .favorites) }

    private func showLibrary(tab: LibraryTab) {
        libraryNavigation.tab = tab
        libraryNavigation.isReviewing = false
        if libraryWindow == nil {
            libraryWindow = makeWindow(
                content: LibraryWindow(
                    history: history,
                    favorites: favorites,
                    navigation: libraryNavigation,
                    languageSettings: languageSettings,
                    lookUpAgain: { [weak self] in self?.lookUpAgain($0) }
                ),
                size: NSSize(width: 860, height: 560)
            )
        }
        show(libraryWindow, title: languageSettings.strings.library)
    }

    func showSettings<Content: View>(content: Content) {
        if settingsWindow == nil {
            settingsWindow = makeWindow(content: content, size: NSSize(width: 700, height: 500))
            settingsWindow?.contentMinSize = NSSize(width: 620, height: 420)
        }
        show(settingsWindow, title: languageSettings.strings.settingsTitle)
    }

    private func makeWindow<Content: View>(content: Content, size: NSSize) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        let hosting = NSHostingController(rootView: content)
        hosting.sceneBridgingOptions = [.toolbars]
        window.contentViewController = hosting
        window.setContentSize(size)
        window.appearance = NSAppearance(named: .darkAqua)
        window.toolbarStyle = .unified
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
