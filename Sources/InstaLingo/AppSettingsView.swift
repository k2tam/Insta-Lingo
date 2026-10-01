import AppKit
import ApplicationServices
import LookupCore
import SwiftUI

struct AppSettingsView: View {
    private enum Pane: String, CaseIterable, Identifiable {
        case general
        case source
        case contexts
        case shortcuts
        case permissions

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .general: "gearshape"
            case .source: "sparkles"
            case .contexts: "text.alignleft"
            case .shortcuts: "keyboard"
            case .permissions: "lock.shield"
            }
        }

        var tint: Color {
            switch self {
            case .general: Color(hex: 0x8E8E93)
            case .source: Theme.accent
            case .contexts: Color(hex: 0xBF5AF2)
            case .shortcuts: Color(hex: 0xFF9F0A)
            case .permissions: Color(hex: 0x30B050)
            }
        }
    }

    let loginSettings: LaunchAtLoginSettings
    let modelConfiguration: LookupModelConfiguration
    let hotkeys: GlobalHotkeyManager
    @Bindable var lookup: LookupCoordinator
    @Bindable var languageSettings: UILanguageSettings
    @State private var selectedPane: Pane? = .general
    @State private var permissions = PermissionStatus.current()

    private var strings: UIStrings { languageSettings.strings }

    var body: some View {
        NavigationSplitView {
            List(Pane.allCases, selection: $selectedPane) { pane in
                HStack(spacing: 9) {
                    Image(systemName: pane.systemImage)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(pane.tint, in: RoundedRectangle(cornerRadius: 6))
                        .accessibilityHidden(true)
                    Text(title(for: pane))
                    Spacer(minLength: 4)
                    if pane == .permissions, !permissions.allGranted {
                        Circle()
                            .fill(Color(hex: 0xFF9F0A))
                            .frame(width: 7, height: 7)
                            .accessibilityLabel(strings.permissionMissing)
                    }
                }
                .tag(pane)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } detail: {
            detail(for: selectedPane ?? .general)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .safeAreaInset(edge: .top, spacing: 0) {
                    Text(title(for: selectedPane ?? .general))
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                }
        }
        .frame(minWidth: 620, idealWidth: 700, minHeight: 420, idealHeight: 500)
        .onAppear { permissions = .current() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissions = .current()
        }
        .environment(\.locale, languageSettings.language.locale)
    }

    private func title(for pane: Pane) -> String {
        switch pane {
        case .general: strings.generalSettings
        case .source: strings.lookupSource
        case .contexts: strings.contextSettings
        case .shortcuts: strings.shortcutsSettings
        case .permissions: strings.permissionsSettings
        }
    }

    @ViewBuilder
    private func detail(for pane: Pane) -> some View {
        switch pane {
        case .general:
            Form {
                Section {
                    Picker(strings.interfaceLanguage, selection: $languageSettings.language) {
                        Text(strings.vietnamese).tag(UILanguage.vietnamese)
                        Text(strings.english).tag(UILanguage.english)
                    }
                    Picker(strings.quickMeaningLanguageSetting, selection: $lookup.quickMeaningLanguage) {
                        Text(strings.targetLanguageName(code: "vi")).tag(TargetLanguage.vietnamese)
                        Text(strings.targetLanguageName(code: "en")).tag(TargetLanguage.simpleEnglish)
                    }
                    LaunchAtLoginSettingsView(settings: loginSettings, strings: strings)
                }
            }
            .formStyle(.grouped)
        case .source:
            Form {
                Section {
                    HStack(spacing: 12) {
                        SourceCard(
                            title: strings.aiModel,
                            message: strings.aiModelSourceSummary,
                            isSelected: lookup.selectedSource == .groq
                        ) { lookup.selectedSource = .groq }
                        SourceCard(
                            title: strings.onThisMac,
                            message: strings.localSourceSummary,
                            isSelected: lookup.selectedSource == .local
                        ) { lookup.selectedSource = .local }
                    }
                    .padding(.vertical, 4)
                }
                if lookup.selectedSource == .groq {
                    ModelSettingsSections(configuration: modelConfiguration, strings: strings)
                }
            }
            .formStyle(.grouped)
        case .contexts:
            ProfessionalContextSettingsView(catalog: lookup.contextCatalog, strings: strings)
        case .shortcuts:
            GlobalHotkeySettingsView(manager: hotkeys, strings: strings)
        case .permissions:
            PermissionsSettingsView(status: permissions, strings: strings)
        }
    }
}

private struct SourceCard: View {
    let title: String
    let message: String
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Theme.accentBright : Theme.textTertiary)
                        .accessibilityHidden(true)
                }
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                isSelected ? Theme.accentBright.opacity(0.14) : Color.white.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Theme.accentBright : Color.white.opacity(0.12),
                                  lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct PermissionStatus: Equatable {
    var accessibility: Bool
    var screenRecording: Bool

    var allGranted: Bool { accessibility && screenRecording }

    /// Reads the current grants without prompting the user.
    static func current() -> PermissionStatus {
        PermissionStatus(
            accessibility: AXIsProcessTrusted(),
            screenRecording: CGPreflightScreenCaptureAccess()
        )
    }
}

private struct PermissionsSettingsView: View {
    let status: PermissionStatus
    let strings: UIStrings

    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                row(
                    granted: status.accessibility,
                    title: strings.accessibilityPermission,
                    message: strings.accessibilityPermissionPurpose,
                    link: SystemSettingsLink.accessibility
                )
                row(
                    granted: status.screenRecording,
                    title: strings.screenRecordingPermission,
                    message: strings.screenRecordingPermissionPurpose,
                    link: SystemSettingsLink.screenRecording
                )
            } footer: {
                Text(strings.permissionsFooter)
            }
        }
        .formStyle(.grouped)
    }

    private func row(granted: Bool, title: String, message: String, link: URL) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(granted ? Theme.success : Color(hex: 0xFF9F0A))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Text(strings.permissionGranted)
                    .foregroundStyle(.secondary)
            } else {
                Button(strings.grantPermission) { openURL(link) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension UIStrings {
    private func settingsText(_ vi: String, _ en: String) -> String {
        language == .vietnamese ? vi : en
    }

    var generalSettings: String { settingsText("Chung", "General") }
    var quickMeaningLanguageSetting: String {
        settingsText("Ngôn ngữ nghĩa nhanh (double-click)", "Quick meaning language (double-click)")
    }
    var settingsTitle: String { settingsText("Cài đặt", "Settings") }
    var shortcutsSettings: String { settingsText("Phím tắt", "Shortcuts") }
    var permissionsSettings: String { settingsText("Quyền truy cập", "Permissions") }
    var permissionMissing: String { settingsText("Thiếu quyền", "Permission needed") }
    var aiModelSourceSummary: String {
        settingsText(
            "Giải nghĩa và ví dụ phong phú hơn. Từ cần tra, ngôn ngữ và ngữ cảnh được gửi đến mô hình AI đã chọn.",
            "Richer explanations and examples. Your word, language and context are sent to the selected AI model."
        )
    }
    var localSourceSummary: String {
        settingsText(
            "Apple Intelligence và Apple Translation. Không có gì rời khỏi máy Mac của bạn.",
            "Apple Intelligence and Translation. Nothing leaves your Mac."
        )
    }
    var accessibilityPermission: String { settingsText("Trợ năng", "Accessibility") }
    var accessibilityPermissionPurpose: String {
        settingsText("Đọc chữ bạn đã bôi đen trong ứng dụng khác.", "Reads the text you selected in other apps.")
    }
    var screenRecordingPermission: String { settingsText("Ghi màn hình", "Screen Recording") }
    var screenRecordingPermissionPurpose: String {
        settingsText(
            "Chỉ cần cho tra vùng màn hình. Mở lại ứng dụng sau khi cấp quyền.",
            "Needed only for screen-region lookup. Reopen the app after granting."
        )
    }
    var permissionsFooter: String {
        settingsText("Insta Lingo chỉ đọc chữ khi bạn nhấn phím tắt.", "Insta Lingo only reads text when you press a shortcut.")
    }
    var permissionGranted: String { settingsText("Đã cấp", "Granted") }
    var grantPermission: String { settingsText("Cấp quyền…", "Grant…") }
}
