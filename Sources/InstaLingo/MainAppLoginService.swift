import LookupCore
import ServiceManagement

@MainActor
struct MainAppLoginService: LaunchAtLoginService {
    private var service: SMAppService { .mainApp }

    var status: LaunchAtLoginStatus {
        switch service.status {
        case .notRegistered: .notRegistered
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        @unknown default: .notFound
        }
    }

    func register() throws { try service.register() }
    func unregister() throws { try service.unregister() }
}
