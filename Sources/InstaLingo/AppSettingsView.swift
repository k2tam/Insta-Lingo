import LookupCore
import SwiftUI

struct AppSettingsView: View {
    private enum Tab: Hashable {
        case general
        case contexts
        case groq
        case hotkeys
    }

    let loginSettings: LaunchAtLoginSettings
    let groqConfiguration: GroqConfiguration
    let hotkeys: GlobalHotkeyManager
    @Bindable var lookup: LookupCoordinator
    @Bindable var languageSettings: UILanguageSettings
    @State private var selectedTab: Tab = .general

    private var strings: UIStrings { languageSettings.strings }

    var body: some View {
        VStack(spacing: 0) {
            Picker(strings.settingsTitle, selection: $selectedTab) {
                Text(strings.generalSettings).tag(Tab.general)
                Text(strings.contextSettings).tag(Tab.contexts)
                Text(strings.groq).tag(Tab.groq)
                Text(strings.hotkeysTitle).tag(Tab.hotkeys)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding()

            Divider()

            Group {
                switch selectedTab {
                case .general:
                    Form {
                        Section(strings.lookupSource) {
                            Picker(strings.lookupSource, selection: $lookup.selectedSource) {
                                Text(strings.groq).tag(LookupSource.groq)
                                Text(strings.local).tag(LookupSource.local)
                            }
                            .labelsHidden()

                            if lookup.selectedSource == .groq {
                                Text(strings.groqDisclosure(model: groqConfiguration.model))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Section(strings.interfaceLanguage) {
                            Picker(strings.interfaceLanguage, selection: $languageSettings.language) {
                                Text(strings.vietnamese).tag(UILanguage.vietnamese)
                                Text(strings.english).tag(UILanguage.english)
                            }
                            .labelsHidden()
                        }

                        Section {
                            LaunchAtLoginSettingsView(settings: loginSettings, strings: strings)
                        }
                    }
                    .formStyle(.grouped)
                    .padding()
                case .groq:
                    GroqSettingsView(configuration: groqConfiguration, strings: strings)
                case .contexts:
                    ProfessionalContextSettingsView(catalog: lookup.contextCatalog, strings: strings)
                case .hotkeys:
                    GlobalHotkeySettingsView(manager: hotkeys, strings: strings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 640, idealWidth: 700, minHeight: 420, idealHeight: 500)
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
