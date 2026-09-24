import Foundation
import Testing
@testable import LookupCore

@Test @MainActor
func geminiStartsDisabledAndCannotRevealKeyUntilEnabled() throws {
    let credentials = InMemoryCredentials()
    let defaults = UserDefaults(suiteName: "GeminiConfigurationTests.\(UUID())")!
    let configuration = GeminiConfiguration(defaults: defaults, credentials: credentials)

    #expect(configuration.isEnabled == false)
    #expect(configuration.hasAPIKey == false)
    #expect(throws: GeminiConfigurationError.disabled) {
        try configuration.keyForSelectedLookup()
    }
    #expect(credentials.readCount == 1) // startup status only

    configuration.setEnabled(true)
    #expect(throws: GeminiConfigurationError.missingKey) {
        try configuration.keyForSelectedLookup()
    }
}

@Test @MainActor
func geminiKeyStaysOutOfPreferencesAndCanBeRemoved() throws {
    let credentials = InMemoryCredentials()
    let defaults = UserDefaults(suiteName: "GeminiConfigurationTests.\(UUID())")!
    let configuration = GeminiConfiguration(defaults: defaults, credentials: credentials)
    configuration.setEnabled(true)
    try configuration.saveAPIKey("  secret-api-key \n")

    #expect(configuration.hasAPIKey)
    #expect(try configuration.keyForSelectedLookup() == "secret-api-key")
    #expect(defaults.dictionaryRepresentation().values.contains { "\($0)".contains("secret-api-key") } == false)

    try configuration.removeAPIKey()
    #expect(configuration.hasAPIKey == false)
    #expect(throws: GeminiConfigurationError.missingKey) {
        try configuration.keyForSelectedLookup()
    }
}

@MainActor
private final class InMemoryCredentials: GeminiCredentialStoring {
    var key: String?
    var readCount = 0
    func read() throws -> String? { readCount += 1; return key }
    func save(_ key: String) throws { self.key = key }
    func delete() throws { key = nil }
}
