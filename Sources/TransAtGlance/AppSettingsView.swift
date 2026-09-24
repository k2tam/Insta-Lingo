import LookupCore
import SwiftUI

struct AppSettingsView: View {
    let loginSettings: LaunchAtLoginSettings
    let geminiConfiguration: GeminiConfiguration
    let fallbackSettings: GeminiFallbackSettings
    let hotkeys: GlobalHotkeyManager
    let languageSettings: UILanguageSettings

    private var strings: UIStrings { languageSettings.strings }

    var body: some View {
        TabView {
            LaunchAtLoginSettingsView(settings: loginSettings, strings: strings)
                .tabItem { Label(strings.generalSettings, systemImage: "gearshape") }
            GeminiSettingsView(configuration: geminiConfiguration, fallbackSettings: fallbackSettings, strings: strings)
                .tabItem { Label(strings.gemini, systemImage: "sparkles") }
            GlobalHotkeySettingsView(manager: hotkeys, strings: strings)
                .tabItem { Label(strings.hotkeysTitle, systemImage: "keyboard") }
        }
        .frame(width: 470)
        .environment(\.locale, languageSettings.language.locale)
    }
}

extension UIStrings {
    var generalSettings: String {
        language == .vietnamese ? "Chung" : "General"
    }
    var settingsTitle: String {
        language == .vietnamese ? "Cài đặt" : "Settings"
    }
}
