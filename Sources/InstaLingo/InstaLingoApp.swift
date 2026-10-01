import AppKit
import SwiftUI
import LookupCore
import Observation

@MainActor @Observable
private final class PanelPresentationState {
    var isDetailExpanded = false
    var inputFocusGeneration = 0
}

/// SwiftUI may recreate the `App` value while it reconciles scenes. Keep the
/// AppKit status item outside that value so each reconstruction cannot add a
/// second menu bar icon.
@MainActor
private enum AppRuntime {
    static let statusPanel = StatusPanelController()
}

@main
struct InstaLingoApp: App {
    @State private var lookup: LookupCoordinator
    @State private var modelConfiguration: LookupModelConfiguration
    @State private var history: LookupHistory
    @State private var favorites: LookupFavorites
    @State private var languageSettings: UILanguageSettings
    @State private var hotkeys: GlobalHotkeyManager
    @State private var loginSettings: LaunchAtLoginSettings
    // Retain the status item and panel for the lifetime of the menu bar app.
    @State private var statusPanel: StatusPanelController
    @State private var supplementaryWindows: SupplementaryWindowsController

    init() {
        // The redesign is dark only: the panel and windows use dark glass.
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        let modelConfiguration = LookupModelConfiguration(credentials: GroqKeychain())
        let groqProvider = LLMProvider(configuration: modelConfiguration)
        groqProvider.warmUp()
        let history = LookupHistory()
        let favorites = LookupFavorites()
        let lookup = LookupCoordinator(
            explainer: LocalFoundationExplainer(),
            translator: LocalAppleTranslator(),
            groq: groqProvider,
            modelConfiguration: modelConfiguration,
            history: history
        )
        let ocrFlow = OCRLookupFlow(recognizer: ScreenRegionOCR())
        let selectionFlow = SelectionLookupFlow(
            reader: AccessibilitySelectedTextReader(previousApp: PreviousAppTracker()),
            fallbackReader: ClipboardSelectedTextReader(),
            // Read when the hotkey fires, before our panel takes focus.
            sourceAppID: { NSWorkspace.shared.frontmostApplication?.bundleIdentifier }
        )
        let languageSettings = UILanguageSettings()
        let supplementaryWindows = SupplementaryWindowsController(
            history: history, favorites: favorites, languageSettings: languageSettings
        )
        let hotkeys = GlobalHotkeyManager()
        let loginSettings = LaunchAtLoginSettings(service: MainAppLoginService())
        let statusPanel = AppRuntime.statusPanel
        let panelState = PanelPresentationState()
        statusPanel.onOpen = { groqProvider.warmUp() }
        statusPanel.onPresent = { shouldFocusInput in
            guard shouldFocusInput else { return }
            panelState.inputFocusGeneration += 1
        }

        statusPanel.setContent(AnyView(
            LookupPanel(
                lookup: lookup,
                ocrFlow: ocrFlow,
                selectionFlow: selectionFlow,
                languageSettings: languageSettings,
                favorites: favorites,
                history: history,
                hotkeys: hotkeys,
                modelConfiguration: modelConfiguration,
                isDetailExpanded: Binding(
                    get: { panelState.isDetailExpanded },
                    set: { panelState.isDetailExpanded = $0 }
                ),
                inputFocusGeneration: Binding(
                    get: { panelState.inputFocusGeneration },
                    set: { panelState.inputFocusGeneration = $0 }
                ),
                hidePanel: { [weak statusPanel] in statusPanel?.hide() },
                showPanel: { [weak statusPanel] in await statusPanel?.showAfterRegionSelection() },
                quitApp: { NSApp.terminate(nil) },
                openHistory: { supplementaryWindows.showHistory() },
                openFavorites: { supplementaryWindows.showFavorites() },
                openSettings: {
                    statusPanel.hide()
                    supplementaryWindows.showSettings(content: AppSettingsView(
                        loginSettings: loginSettings,
                        modelConfiguration: modelConfiguration,
                        hotkeys: hotkeys,
                        lookup: lookup,
                        languageSettings: languageSettings
                    ))
                }
            )
            .frame(width: 480)
        ))

        supplementaryWindows.lookUpAgain = { [weak statusPanel] text in
            selectionFlow.reset()
            ocrFlow.cancelReview()
            lookup.text = text
            statusPanel?.show(focusInput: false)
            Task { await lookup.submit() }
        }

        hotkeys.onAction = { [weak statusPanel] action in
            switch action {
            case .openPanel:
                groqProvider.warmUp()
                statusPanel?.show()
            case .selectedText:
                // Read before activating our popover. Some source apps clear
                // their selection as soon as another application takes focus.
                Task {
                    await selectionFlow.start(lookup: lookup, onSelectionRead: {
                        Task { await statusPanel?.showAfterActivation(focusInput: false) }
                    })
                    await statusPanel?.showAfterActivation(focusInput: false)
                }
            case .screenRegion:
                selectionFlow.reset()
                Task {
                    await ocrFlow.start(
                        lookup: lookup,
                        hidePanel: { [weak statusPanel] in statusPanel?.hide() },
                        showPanel: { [weak statusPanel] in await statusPanel?.showAfterRegionSelection() }
                    )
                }
            }
        }

        _history = State(initialValue: history)
        _modelConfiguration = State(initialValue: modelConfiguration)
        _favorites = State(initialValue: favorites)
        _lookup = State(initialValue: lookup)
        _languageSettings = State(initialValue: languageSettings)
        _hotkeys = State(initialValue: hotkeys)
        _loginSettings = State(initialValue: loginSettings)
        _statusPanel = State(initialValue: statusPanel)
        _supplementaryWindows = State(initialValue: supplementaryWindows)
    }

    var body: some Scene {
        Settings {
            AppSettingsView(
                loginSettings: loginSettings,
                modelConfiguration: modelConfiguration,
                hotkeys: hotkeys,
                lookup: lookup,
                languageSettings: languageSettings
            )
        }
    }
}
