import Foundation
import Testing
@testable import LookupCore

@MainActor
private final class FakeLoginService: LaunchAtLoginService {
    var status: LaunchAtLoginStatus = .notRegistered
    var registerCount = 0
    var unregisterCount = 0
    var shouldFail = false

    func register() throws {
        registerCount += 1
        if shouldFail { throw TestError.denied }
        status = .enabled
    }

    func unregister() throws {
        unregisterCount += 1
        if shouldFail { throw TestError.denied }
        status = .notRegistered
    }
}

private enum TestError: LocalizedError {
    case denied
    var errorDescription: String? { "Registration denied" }
}

@Test @MainActor
func launchAtLoginDefaultsOffAndUsesPersistentSystemRegistration() {
    let service = FakeLoginService()
    let settings = LaunchAtLoginSettings(service: service)
    #expect(!settings.isEnabled)
    #expect(service.registerCount == 0)

    settings.setEnabled(true)
    #expect(settings.isEnabled)
    #expect(service.registerCount == 1)

    let reopened = LaunchAtLoginSettings(service: service)
    #expect(reopened.isEnabled)
    reopened.setEnabled(false)
    #expect(!reopened.isEnabled)
    #expect(service.unregisterCount == 1)
}

@Test @MainActor
func loginApprovalAndExternalChangesAreReflected() {
    let service = FakeLoginService()
    service.status = .requiresApproval
    let settings = LaunchAtLoginSettings(service: service)
    #expect(settings.isEnabled)

    service.status = .notRegistered
    settings.refreshStatus()
    #expect(!settings.isEnabled)

    settings.setEnabled(false)
    #expect(service.unregisterCount == 0)
}

@Test @MainActor
func failedRegistrationKeepsActualStatusAndExplainsFailure() {
    let service = FakeLoginService()
    service.shouldFail = true
    let settings = LaunchAtLoginSettings(service: service)
    settings.setEnabled(true)
    #expect(!settings.isEnabled)
    #expect(settings.errorMessage == "Registration denied")
}
