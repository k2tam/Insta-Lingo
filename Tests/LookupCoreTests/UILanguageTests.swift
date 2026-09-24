import Foundation
import Testing
@testable import LookupCore

@Test @MainActor
func interfaceLanguagePersistsIndependentlyOfLookupLanguage() {
    let defaults = UserDefaults(suiteName: "TransAtGlance.UILanguageTests.\(UUID().uuidString)")!
    let settings = UILanguageSettings(defaults: defaults)
    #expect(settings.language == .vietnamese)
    #expect(settings.strings.lookup == "Tra nghĩa")

    settings.language = .english
    let reopened = UILanguageSettings(defaults: defaults)
    #expect(reopened.language == .english)
    #expect(reopened.strings.lookup == "Look up")
    #expect(defaults.string(forKey: "lookup.targetLanguage") == nil)
}

@Test @MainActor
func invalidSavedLanguageFallsBackToVietnamese() {
    let defaults = UserDefaults(suiteName: "TransAtGlance.UILanguageTests.\(UUID().uuidString)")!
    defaults.set("fr", forKey: UILanguageSettings.storageKey)
    #expect(UILanguageSettings(defaults: defaults).language == .vietnamese)
}

@Test
func localizedMessagesCoverCurrentLookupAndPermissionFailures() {
    let vietnamese = UIStrings(language: .vietnamese)
    let english = UIStrings(language: .english)
    let permission = "Screen Recording permission is needed to read the region you select. Enable TransAtGlance in System Settings → Privacy & Security → Screen & System Audio Recording, then try again."
    #expect(vietnamese.errorMessage(permission).contains("Ghi màn hình"))
    #expect(english.errorMessage(permission) == permission)
    #expect(vietnamese.errorMessage("Enter an English word or short phrase to look up.") == "Nhập từ hoặc cụm tiếng Anh cần tra.")
    #expect(vietnamese.errorMessage("English to Japanese is not supported by Apple Translation on this Mac. Your lookup was not sent to another provider.").contains("Japanese"))
    #expect(vietnamese.resultDetail("Translated on this Mac from English to Vietnamese.") == "Đã dịch trên máy từ tiếng Anh sang Vietnamese.")
    #expect(vietnamese.contextName(id: "general", customName: "General") == "Thông thường")
    #expect(english.contextName(id: "custom-1", customName: "Biology") == "Biology")
}
