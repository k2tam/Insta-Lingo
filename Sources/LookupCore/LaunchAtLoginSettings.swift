import Observation

public enum LaunchAtLoginStatus: Sendable, Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound

    public var isRequested: Bool {
        self == .enabled || self == .requiresApproval
    }
}

@MainActor
public protocol LaunchAtLoginService {
    var status: LaunchAtLoginStatus { get }
    func register() throws
    func unregister() throws
}

/// The system registration is persistent, so no second preference value is stored.
@MainActor @Observable
public final class LaunchAtLoginSettings {
    public private(set) var status: LaunchAtLoginStatus
    public private(set) var errorMessage: String?

    @ObservationIgnored private let service: any LaunchAtLoginService

    public var isEnabled: Bool { status.isRequested }

    public init(service: any LaunchAtLoginService) {
        self.service = service
        status = service.status
    }

    public func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        errorMessage = nil
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        refreshStatus()
    }

    public func refreshStatus() {
        let currentStatus = service.status
        if currentStatus != status { errorMessage = nil }
        status = currentStatus
    }
}
