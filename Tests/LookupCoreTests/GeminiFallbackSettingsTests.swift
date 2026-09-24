import Foundation
import Testing
@testable import LookupCore

@Test @MainActor
func fallbackChoiceStartsAtAskAndSurvivesRelaunch() {
    let defaults = UserDefaults(suiteName: "GeminiFallbackSettingsTests.\(UUID())")!
    let initial = GeminiFallbackSettings(defaults: defaults)
    #expect(initial.choice == .ask)

    initial.choice = .allow
    #expect(GeminiFallbackSettings(defaults: defaults).choice == .allow)

    initial.choice = .decline
    #expect(GeminiFallbackSettings(defaults: defaults).choice == .decline)

    initial.choice = .ask
    #expect(GeminiFallbackSettings(defaults: defaults).choice == .ask)
}
