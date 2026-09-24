import Foundation
import Testing
@testable import LookupCore

@Test @MainActor
func successfulHistorySurvivesRestartWithLanguageContextAndResult() throws {
    let (url, defaults) = historyFixture()
    let history = LookupHistory(fileURL: url, preferences: defaults)
    let result = LookupResult(meaning: "A task can proceed independently.",
                              example: "The actor processes concurrent work.",
                              detail: "Used in software development.")
    try history.record(text: "concurrent", targetLanguage: .simpleEnglish,
                       context: .softwareDevelopment, result: result)

    let reopened = LookupHistory(fileURL: url, preferences: defaults)
    #expect(reopened.entries.count == 1)
    #expect(reopened.entries[0].text == "concurrent")
    #expect(reopened.entries[0].targetLanguageCode == "en")
    #expect(reopened.entries[0].context == .softwareDevelopment)
    #expect(reopened.entries[0].result == result)
    #expect(reopened.search("ACTOR").count == 1)
    #expect(reopened.search("missing").isEmpty)
}

@Test @MainActor
func disablingAndClearingHistorySurviveRestart() throws {
    let (url, defaults) = historyFixture()
    let history = LookupHistory(fileURL: url, preferences: defaults)
    let result = LookupResult(meaning: "Meaning", example: "Example", detail: "Detail")
    try history.record(text: "first", targetLanguage: .vietnamese,
                       context: .general, result: result)
    history.isEnabled = false
    try history.record(text: "ignored", targetLanguage: .vietnamese,
                       context: .general, result: result)

    let reopened = LookupHistory(fileURL: url, preferences: defaults)
    #expect(!reopened.isEnabled)
    #expect(reopened.entries.map(\.text) == ["first"])
    try reopened.clear()
    #expect(LookupHistory(fileURL: url, preferences: defaults).entries.isEmpty)
}

@Test @MainActor
func lookupFlowRecordsSuccessButNotFailure() async {
    let (url, defaults) = historyFixture()
    let history = LookupHistory(fileURL: url, preferences: defaults)
    let provider = HistorySequenceExplainer()
    let lookup = LookupCoordinator(explainer: provider, history: history,
                                   preferences: defaults)
    lookup.selectedLanguage = .simpleEnglish

    lookup.text = "actor"
    await lookup.submit()
    #expect(lookup.phase == .result)

    lookup.text = "unavailable"
    await lookup.submit()
    #expect(lookup.phase == .error("Provider unavailable"))

    let reopened = LookupHistory(fileURL: url, preferences: defaults)
    #expect(reopened.entries.map(\.text) == ["actor"])
}

@MainActor
private final class HistorySequenceExplainer: LocalExplaining {
    private var calls = 0

    func explain(_ request: LookupRequest) async throws -> LookupResult {
        calls += 1
        if calls > 1 { throw HistoryProviderError.unavailable }
        return LookupResult(meaning: "A unit of concurrent work.",
                            example: "An actor handles messages.", detail: "")
    }
}

private enum HistoryProviderError: LocalizedError {
    case unavailable
    var errorDescription: String? { "Provider unavailable" }
}

private func historyFixture() -> (URL, UserDefaults) {
    let id = UUID().uuidString
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("TransAtGlance-HistoryTests-\(id)", isDirectory: true)
        .appendingPathComponent("history.json")
    return (url, UserDefaults(suiteName: "TransAtGlance.HistoryTests.\(id)")!)
}
