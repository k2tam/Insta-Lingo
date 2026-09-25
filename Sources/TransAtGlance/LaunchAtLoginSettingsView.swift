import LookupCore
import SwiftUI

struct LaunchAtLoginSettingsView: View {
    let settings: LaunchAtLoginSettings
    let strings: UIStrings

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            Toggle(strings.launchAtLogin, isOn: Binding(
                get: { settings.isEnabled },
                set: { settings.setEnabled($0) }
            ))
            .disabled(settings.status == .notFound)

            if settings.status == .requiresApproval {
                Text(strings.launchAtLoginApprovalNeeded)
                    .foregroundStyle(.secondary)
            } else if settings.status == .notFound {
                Text(strings.launchAtLoginUnavailable)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = settings.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }
        .onAppear { settings.refreshStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { settings.refreshStatus() }
        }
    }
}

extension UIStrings {
    var launchAtLogin: String {
        language == .vietnamese ? "Mở TransAtGlance khi đăng nhập" : "Open TransAtGlance at login"
    }

    var launchAtLoginApprovalNeeded: String {
        language == .vietnamese
            ? "Đã yêu cầu mở khi đăng nhập. Hãy cho phép TransAtGlance trong Cài đặt hệ thống → Cài đặt chung → Mục đăng nhập."
            : "Launch at login was requested. Allow TransAtGlance in System Settings → General → Login Items."
    }

    var launchAtLoginUnavailable: String {
        language == .vietnamese
            ? "Không tìm thấy ứng dụng để đăng ký mở khi đăng nhập. Hãy chạy TransAtGlance từ gói ứng dụng đã cài đặt."
            : "The app could not be registered as a login item. Run TransAtGlance from an installed app bundle."
    }
}
