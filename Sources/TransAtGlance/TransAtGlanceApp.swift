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
struct TransAtGlanceApp: App {
    @State private var lookup: LookupCoordinator
    @State private var groqConfiguration: GroqConfiguration
    @State private var history: LookupHistory
    @State private var favorites: LookupFavorites
    @State private var languageSettings: UILanguageSettings
    @State private var hotkeys: GlobalHotkeyManager
    @State private var loginSettings: LaunchAtLoginSettings
    // Retain the status item and panel for the lifetime of the menu bar app.
    @State private var statusPanel: StatusPanelController
    @State private var supplementaryWindows: SupplementaryWindowsController

    init() {
        let groqConfiguration = GroqConfiguration(credentials: GroqKeychain())
        let history = LookupHistory()
        let favorites = LookupFavorites()
        let lookup = LookupCoordinator(
            explainer: LocalFoundationExplainer(),
            translator: LocalAppleTranslator(),
            groq: GroqProvider(configuration: groqConfiguration),
            groqConfiguration: groqConfiguration,
            history: history
        )
        let ocrFlow = OCRLookupFlow(recognizer: ScreenRegionOCR())
        let selectionFlow = SelectionLookupFlow(
            reader: AccessibilitySelectedTextReader(previousApp: PreviousAppTracker())
        )
        let languageSettings = UILanguageSettings()
        let supplementaryWindows = SupplementaryWindowsController(
            history: history, favorites: favorites, languageSettings: languageSettings
        )
        let hotkeys = GlobalHotkeyManager()
        let loginSettings = LaunchAtLoginSettings(service: MainAppLoginService())
        let statusPanel = AppRuntime.statusPanel
        let panelState = PanelPresentationState()
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
                        groqConfiguration: groqConfiguration,
                        hotkeys: hotkeys,
                        lookup: lookup,
                        languageSettings: languageSettings
                    ))
                }
            )
            .frame(width: 680)
        ))

        hotkeys.onAction = { [weak statusPanel] action in
            switch action {
            case .openPanel:
                statusPanel?.show()
            case .selectedText:
                statusPanel?.show(focusInput: false)
                Task { await selectionFlow.start(lookup: lookup) }
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
        _groqConfiguration = State(initialValue: groqConfiguration)
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
                groqConfiguration: groqConfiguration,
                hotkeys: hotkeys,
                lookup: lookup,
                languageSettings: languageSettings
            )
        }
    }
}
