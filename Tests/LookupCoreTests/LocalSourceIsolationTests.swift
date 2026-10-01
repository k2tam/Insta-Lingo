import Foundation
import Testing
@testable import LookupCore

@Test @MainActor
func localFailureDoesNotSwitchToGroq() async {
    let groq = IsolationRecordingGroq()
    let configuration = LookupModelConfiguration(credentials: EmptyGroqCredentials())
    let lookup = LookupCoordinator(
        explainer: UnavailableExplainer(),
        groq: groq,
        modelConfiguration: configuration,
        preferences: UserDefaults(suiteName: "LocalSourceIsolationTests.\(UUID())")!
    )
    lookup.selectedSource = .local
    lookup.selectedLanguage = .simpleEnglish
    lookup.text = "actor"

    await lookup.submit()

    #expect(lookup.phase == .error("Apple Intelligence is unavailable."))
    #expect(groq.requests.isEmpty)
}

@MainActor
private struct UnavailableExplainer: LocalExplaining {
    func explain(_ request: LookupRequest) async throws -> LookupResult {
        throw UnavailableError()
    }
}

private struct UnavailableError: LocalizedError, LocalLookupUnavailable {
    var errorDescription: String? { "Apple Intelligence is unavailable." }
}

@MainActor
private struct EmptyGroqCredentials: GroqCredentialStoring {
    func read(account: String) throws -> String? { nil }
    func save(_ key: String, account: String) throws {}
    func delete(account: String) throws {}
}

@MainActor
private final class IsolationRecordingGroq: GroqLookupProviding {
    var requests: [LookupRequest] = []

    func lookup(_ request: LookupRequest, to target: TargetLanguage, route: LookupRoute, depth: LookupDepth) async throws -> LookupResult {
        requests.append(request)
        return LookupResult(meaning: "groq", example: "example", detail: "")
    }
}
