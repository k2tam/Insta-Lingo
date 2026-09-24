import SwiftUI
import LookupCore
import Observation

@MainActor @Observable
private final class PanelPresentationState {
    var isDetailExpanded = false
}

@main
struct TransAtGlanceApp: App {
    @State private var lookup: LookupCoordinator
    @State private var geminiConfiguration: GeminiConfiguration
    @State private var fallbackSettings: GeminiFallbackSettings
    @State private var history: LookupHistory
    @State private var favorites: LookupFavorites
    @State private var languageSettings: UILanguageSettings
    @State private var hotkeys: GlobalHotkeyManager
    @State private var loginSettings: LaunchAtLoginSettings
    // Retain the status item and panel for the lifetime of the menu bar app.
    @State private var statusPanel: StatusPanelController
    @State private var supplementaryWindows: SupplementaryWindowsController

    init() {
        let configuration = GeminiConfiguration(credentials: GeminiKeychain())
        let fallback = GeminiFallbackSettings()
        let history = LookupHistory()
        let favorites = LookupFavorites()
        let lookup = LookupCoordinator(
            explainer: LocalFoundationExplainer(),
            translator: LocalAppleTranslator(),
            gemini: GeminiProvider(),
            geminiConfiguration: configuration,
            fallbackSettings: fallback,
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
        let statusPanel = StatusPanelController()
        let panelState = PanelPresentationState()

        statusPanel.setContent(AnyView(
            LookupPanel(
                lookup: lookup,
                ocrFlow: ocrFlow,
                selectionFlow: selectionFlow,
                languageSettings: languageSettings,
                geminiConfiguration: configuration,
                favorites: favorites,
                isDetailExpanded: Binding(
                    get: { panelState.isDetailExpanded },
                    set: { panelState.isDetailExpanded = $0 }
                ),
                hidePanel: { [weak statusPanel] in statusPanel?.hide() },
                showPanel: { [weak statusPanel] in statusPanel?.show() },
                openHistory: { supplementaryWindows.showHistory() },
                openFavorites: { supplementaryWindows.showFavorites() },
                openSettings: {
                    supplementaryWindows.showSettings(content: AppSettingsView(
                        loginSettings: loginSettings,
                        geminiConfiguration: configuration,
                        fallbackSettings: fallback,
                        hotkeys: hotkeys,
                        languageSettings: languageSettings
                    ))
                }
            )
            .frame(width: 340)
        ))

        hotkeys.onAction = { [weak statusPanel] action in
            switch action {
            case .openPanel:
                statusPanel?.show()
            case .selectedText:
                statusPanel?.show()
                Task { await selectionFlow.start(lookup: lookup, reviewSelection: true) }
            case .screenRegion:
                selectionFlow.reset()
                Task {
                    await ocrFlow.start(
                        lookup: lookup,
                        hidePanel: { [weak statusPanel] in statusPanel?.hide() },
                        showPanel: { [weak statusPanel] in statusPanel?.show() }
                    )
                }
            }
        }

        _geminiConfiguration = State(initialValue: configuration)
        _fallbackSettings = State(initialValue: fallback)
        _history = State(initialValue: history)
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
                geminiConfiguration: geminiConfiguration,
                fallbackSettings: fallbackSettings,
                hotkeys: hotkeys,
                languageSettings: languageSettings
            )
        }
    }
}
