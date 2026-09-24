import Foundation
import Testing
@testable import LookupCore

@Test @MainActor
func favoritesKeepSeparateResultsForEachLanguageAndContext() throws {
    let url = favoritesFixture()
    let favorites = LookupFavorites(fileURL: url)

    try favorites.save(text: "actor", targetLanguage: .vietnamese,
                       context: .general,
                       result: LookupResult(meaning: "diễn viên", example: "The actor bowed.", detail: "stage"))
    try favorites.save(text: "actor", targetLanguage: .simpleEnglish,
                       context: .general,
                       result: LookupResult(meaning: "A person who performs.", example: "The actor bowed.", detail: ""))
    try favorites.save(text: "actor", targetLanguage: .simpleEnglish,
                       context: .softwareDevelopment,
                       result: LookupResult(meaning: "An isolated unit.", example: "The actor handles messages.", detail: "Swift concurrency"))

    let reopened = LookupFavorites(fileURL: url)
    #expect(reopened.search("actor").count == 3)
    #expect(reopened.entries.map(\.targetLanguageCode) == ["en", "en", "vi"])
    #expect(reopened.entries[0].context == .softwareDevelopment)
    #expect(reopened.entries[0].result.meaning == "An isolated unit.")
    #expect(reopened.search("Swift concurrency").map(\.result.meaning) == ["An isolated unit."])
}

@Test @MainActor
func clearingHistoryKeepsFavoritesAfterRestart() throws {
    let favoriteURL = favoritesFixture()
    let historyURL = favoriteURL.deletingLastPathComponent().appendingPathComponent("history.json")
    let defaults = UserDefaults(suiteName: "TransAtGlance.FavoritesTests.\(UUID().uuidString)")!
    let history = LookupHistory(fileURL: historyURL, preferences: defaults)
    let favorites = LookupFavorites(fileURL: favoriteURL)
    let result = LookupResult(meaning: "diễn viên", example: "The actor bowed.", detail: "stage")

    try history.record(text: "actor", targetLanguage: .vietnamese,
                       context: .general, result: result)
    try favorites.save(text: "actor", targetLanguage: .vietnamese,
                       context: .general, result: result)
    try history.clear()

    #expect(LookupHistory(fileURL: historyURL, preferences: defaults).entries.isEmpty)
    let reopenedFavorites = LookupFavorites(fileURL: favoriteURL)
    #expect(reopenedFavorites.entries.count == 1)
    #expect(reopenedFavorites.entries[0].result == result)
}

private func favoritesFixture() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("TransAtGlance-FavoritesTests-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("favorites.json")
}
