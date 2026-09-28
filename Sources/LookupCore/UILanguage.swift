import Foundation
import Observation

/// The app's interface language is independent of the lookup target language.
public enum UILanguage: String, CaseIterable, Identifiable, Sendable {
    case vietnamese = "vi"
    case english = "en"

    public var id: String { rawValue }
    public var locale: Locale { Locale(identifier: rawValue) }
}

@MainActor @Observable
public final class UILanguageSettings {
    public static let storageKey = "interface.language"

    public var language: UILanguage {
        didSet { defaults.set(language.rawValue, forKey: Self.storageKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    public var strings: UIStrings { UIStrings(language: language) }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = defaults.string(forKey: Self.storageKey)
            .flatMap(UILanguage.init(rawValue:)) ?? .vietnamese
    }
}

/// Keep user-facing copy here so a new flow must provide both languages.
public struct UIStrings: Sendable {
    public let language: UILanguage

    public init(language: UILanguage) { self.language = language }

    private func choose(_ vi: String, _ en: String) -> String {
        language == .vietnamese ? vi : en
    }

    public var interfaceLanguage: String { choose("Ngôn ngữ giao diện", "Interface language") }
    public var vietnamese: String { "Tiếng Việt" }
    public var english: String { "English" }
    public var inputPlaceholder: String { choose("Từ hoặc cụm tiếng Anh", "English word or short phrase") }
    public var reviewCapturedText: String { choose("Kiểm tra chữ trong ô; với đoạn dài, bôi đen từ hoặc cụm cần tra rồi bấm Tra nghĩa.", "Review the text in the field; for a longer passage, select the word or phrase to look up, then press Look up.") }
    public var inputAccessibility: String { choose("Từ hoặc cụm cần tra", "Word or short phrase to look up") }
    public var resultLanguage: String { choose("Ngôn ngữ kết quả", "Result language") }
    public var simpleEnglish: String { choose("Tiếng Anh đơn giản", "Simple English") }
    public var local: String { choose("Apple trên máy", "Apple on-device") }
    public var lookup: String { choose("Tra nghĩa", "Look up") }
    public var retryLookup: String { choose("Thử lại", "Try again") }
    public var lookupFailed: String { choose("Chưa thể hoàn tất lượt tra", "The lookup could not be completed") }
    public var copyResult: String { choose("Sao chép", "Copy") }
    public var copiedResult: String { choose("Đã sao chép", "Copied") }
    public var showLess: String { choose("Thu gọn", "Show less") }
    public var resultExample: String { choose("Ví dụ", "Example") }
    public var historyTitle: String { choose("Lịch sử tra", "Lookup history") }
    public var quitApp: String { choose("Thoát ứng dụng", "Quit") }
    public var idle: String { choose("Nhập từ hoặc cụm ngắn để xem nghĩa.", "Type a word or short phrase to see its meaning.") }
    public var loading: String { choose("Đang tra trên máy…", "Looking up on this Mac…") }
    public var moreDetail: String { choose("Xem thêm", "More detail") }
    public var vietnameseExplanation: String { choose("Xem giải nghĩa tiếng Việt", "Show Vietnamese explanation") }
    public var loadingVietnamese: String { choose("Đang tra giải nghĩa tiếng Việt…", "Loading Vietnamese explanation…") }
    public var retryVietnamese: String { choose("Thử lại", "Retry") }
    public var quickMeaning: String { choose("Nghĩa nhanh", "Quick meaning") }
    public var quickMeaningLoading: String { choose("Đang tra nghĩa nhanh…", "Looking up a quick meaning…") }
    public var closeQuickMeaning: String { choose("Đóng nghĩa nhanh", "Close quick meaning") }
    public func quickMeaningHint(primary: String) -> String {
        choose(
            "Double-click một từ tiếng Anh để xem nghĩa nhanh, không rời khỏi \(primary).",
            "Double-click an English word for a quick meaning without leaving \(primary)."
        )
    }
    public func quickMeaningKeepsPrimary(_ primary: String) -> String {
        choose(
            "Kết quả “\(primary)” vẫn được giữ nguyên",
            "The “\(primary)” result stays in place"
        )
    }
    public var moreActions: String { choose("Tác vụ khác", "More actions") }
    public var storageUnavailable: String { choose("Không thể lưu dữ liệu trên máy. Hãy kiểm tra dung lượng và quyền truy cập rồi thử lại.", "Could not save data on this Mac. Check storage space and permissions, then try again.") }
    public var newContext: String { choose("Ngữ cảnh mới…", "New context…") }
    public var professionalContext: String { choose("Ngữ cảnh chuyên môn", "Professional context") }
    public var newProfessionalContext: String { choose("Ngữ cảnh chuyên môn mới", "New professional context") }
    public var editProfessionalContext: String { choose("Sửa ngữ cảnh chuyên môn", "Edit professional context") }
    public var contextSettings: String { choose("Ngữ cảnh", "Contexts") }
    public var availableContexts: String { choose("Ngữ cảnh hiện có", "Available contexts") }
    public var showInLookupWindow: String { choose("Hiện trong cửa sổ tra nghĩa", "Show in lookup window") }
    public var contextVisibilityHint: String { choose("Chọn ngữ cảnh sẽ hiện trong cửa sổ tra nghĩa. Luôn cần ít nhất một ngữ cảnh.", "Choose which contexts appear in the lookup window. At least one must remain visible.") }
    public var selectedContext: String { choose("Dùng khi tra", "Use for lookups") }
    public var contextSelectionHint: String { choose("Ngữ cảnh đã chọn được dùng cho các lượt tra tiếp theo.", "The selected context is used for future lookups.") }
    public var customContexts: String { choose("Ngữ cảnh tự tạo", "Custom contexts") }
    public var editContext: String { choose("Sửa", "Edit") }
    public var deleteContext: String { choose("Xóa", "Delete") }
    public var deleteContextConfirmation: String { choose("Xóa ngữ cảnh này?", "Delete this context?") }
    public var saveContext: String { choose("Lưu", "Save") }
    public var contextName: String { choose("Tên", "Name") }
    public var contextNameAccessibility: String { choose("Tên ngữ cảnh", "Context name") }
    public var contextDescription: String { choose("Mô tả ngắn", "Short description") }
    public var contextDescriptionAccessibility: String { choose("Mô tả ngữ cảnh", "Context description") }
    public var invalidContext: String { choose("Nhập tên riêng biệt và mô tả ngắn.", "Enter a unique name and a short description.") }
    public var cancel: String { choose("Hủy", "Cancel") }
    public var addContext: String { choose("Thêm ngữ cảnh", "Add context") }
    public var generalContext: String { choose("Thông thường", "General") }
    public var softwareContext: String { choose("Phát triển phần mềm", "Software Development") }
    public var swiftContext: String { "Swift/iOS" }

    public func contextName(id: String, customName: String) -> String {
        switch id {
        case "general" where customName == ProfessionalContext.general.name: generalContext
        case "software-development" where customName == ProfessionalContext.softwareDevelopment.name: softwareContext
        case "swift-ios" where customName == ProfessionalContext.swiftIOS.name: swiftContext
        default: customName
        }
    }

    public func contextDescription(id: String, customDescription: String) -> String {
        switch id {
        case "general" where customDescription == ProfessionalContext.general.description: choose("Cách dùng tiếng Anh hằng ngày, không thuộc lĩnh vực chuyên môn.", "Everyday English usage without a specialized field.")
        case "software-development" where customDescription == ProfessionalContext.softwareDevelopment.description: choose("Thuật ngữ thiết kế phần mềm, lập trình và kỹ thuật.", "Software design, programming, and engineering terminology.")
        case "swift-ios" where customDescription == ProfessionalContext.swiftIOS.description: choose("Thuật ngữ ngôn ngữ Swift và phát triển ứng dụng Apple.", "Swift language and Apple app development terminology.")
        default: customDescription
        }
    }

    public func professionalContextAccessibility(_ context: String) -> String {
        choose("Ngữ cảnh chuyên môn: \(context)", "Professional context: \(context)")
    }

    public func targetLanguageName(code: String) -> String {
        if code == "en" { return simpleEnglish }
        return language.locale.localizedString(forLanguageCode: code) ?? code
    }

    public var selectRegion: String { choose("Chọn vùng màn hình", "Select screen region") }
    public var selectRegionAccessibility: String { choose("Chọn vùng màn hình để nhận diện chữ", "Select screen region for text recognition") }
    public var selectingRegionHint: String { choose("Kéo khoanh chữ, hoặc nhấn Escape để hủy.", "Drag around the text, or press Escape to cancel.") }
    public var recognizingRegion: String { choose("Đang nhận diện chữ trong vùng chọn…", "Recognizing text in the selected region…") }
    public var lookupSelection: String { choose("Tra chữ đang bôi đen", "Look up selected text") }
    public var readingSelection: String { choose("Đang đọc phần chữ đã chọn…", "Reading selected text…") }
    public var accessibilityPermissionNeeded: String { choose("Cần quyền Trợ năng để đọc chữ đã bôi đen. Cấp quyền cho Insta Lingo trong Cài đặt hệ thống → Quyền riêng tư & Bảo mật → Trợ năng, rồi thử lại.", "Accessibility permission is needed to read selected text. Enable Insta Lingo in System Settings → Privacy & Security → Accessibility, then try again.") }
    public var retrySelection: String { choose("Thử đọc lại", "Retry selection") }
    public var selectionUnavailable: String { choose("Không đọc được chữ đang bôi đen trong ứng dụng trước đó. Bạn có thể chọn vùng màn hình để nhận diện chữ.", "The previous app did not provide selected text. You can select a screen region to recognize it.") }
    public var selectRegionInstead: String { choose("Chọn vùng thay thế", "Select region instead") }
    public var groq: String { "Groq" }
    public var modelSettings: String { choose("Model dịch", "Lookup model") }
    public var groqModel: String { choose("Model", "Model") }
    public var reasoningEffort: String { choose("Mức suy luận", "Reasoning effort") }
    public func reasoningEffortName(_ effort: GroqReasoningEffort) -> String {
        switch effort {
        case .low: choose("Thấp", "Low")
        case .medium: choose("Vừa", "Medium")
        case .high: choose("Cao", "High")
        }
    }
    public var groqAPIKey: String { choose("Khóa Groq API", "Groq API key") }
    public var saveKey: String { choose("Lưu khóa", "Save key") }
    public var pasteKey: String { choose("Dán khóa từ clipboard", "Paste key from clipboard") }
    public var removeKey: String { choose("Xóa khóa", "Remove key") }
    public var apiKeySaved: String { choose("Đã lưu khóa API", "API key saved") }
    public func groqDisclosure(model: GroqModel) -> String {
        choose(
            "Khi chọn Groq, nội dung tra, ngôn ngữ kết quả và ngữ cảnh đã chọn sẽ được gửi đến Groq để xử lý bằng \(model.rawValue).",
            "When Groq is selected, the lookup text, result language, and selected context are sent to Groq for processing by \(model.rawValue)."
        )
    }
    public var lookupSource: String { choose("Nguồn tra nghĩa", "Lookup source") }
    public var groqLoading: String { choose("Đang tra bằng Groq…", "Looking up with Groq…") }

    /// Core and system adapters currently expose localizedDescription as text.
    /// Translate their known messages at the UI boundary; unknown errors remain
    /// visible so the user still gets a useful diagnosis.
    public func errorMessage(_ message: String) -> String {
        let known: [String: String] = [
            "Enter an English word or short phrase to look up.": "Nhập từ hoặc cụm tiếng Anh cần tra.",
            "Select an English word or short phrase in the text before looking it up.": "Bôi đen một từ hoặc cụm tiếng Anh trong ô trước khi tra.",
            "Local translation is unavailable on this Mac. Your lookup was not sent to another provider.": "Máy Mac này không thể dịch trên máy. Nội dung tra chưa được gửi đến dịch vụ khác.",
            "This Mac does not support Apple Intelligence.": "Máy Mac này không hỗ trợ Apple Intelligence.",
            "Turn on Apple Intelligence in System Settings to use Local lookup.": "Bật Apple Intelligence trong Cài đặt hệ thống để tra nghĩa trên máy.",
            "The on-device model is not ready yet. Try again after it finishes downloading.": "Mô hình trên máy chưa sẵn sàng. Hãy thử lại sau khi tải xong.",
            "The on-device model is unavailable right now.": "Mô hình trên máy hiện không khả dụng.",
            "The on-device model did not return a usable explanation. Try again.": "Mô hình trên máy không trả về giải nghĩa dùng được. Hãy thử lại.",
            "Apple Translation did not return a usable translation. Try again.": "Apple Translation không trả về bản dịch dùng được. Hãy thử lại.",
            "The on-device model did not return a usable explanation and example. Try again.": "Mô hình trên máy không trả về giải nghĩa và ví dụ dùng được. Hãy thử lại.",
            "Apple Translation could not translate the explanation and example. Try again.": "Apple Translation không thể dịch giải nghĩa và ví dụ. Hãy thử lại.",
            "Apple Translation did not return a usable explanation and example. Try again.": "Apple Translation không trả về giải nghĩa và ví dụ dùng được. Hãy thử lại.",
            "No readable text was found in the selected region. Try selecting a clearer area.": "Không tìm thấy chữ đọc được trong vùng chọn. Hãy chọn vùng rõ hơn.",
            "macOS did not authorize this screen capture. Enable Insta Lingo in System Settings → Privacy & Security → Screen & System Audio Recording, then quit and reopen the app.": "macOS chưa cho phép chụp vùng màn hình này. Hãy bật Insta Lingo trong Cài đặt hệ thống → Quyền riêng tư & Bảo mật → Ghi màn hình & âm thanh hệ thống, rồi thoát hẳn và mở lại ứng dụng.",
            "Could not capture the selected screen. Try again.": "Không thể chụp vùng màn hình đã chọn. Hãy thử lại.",
            "Groq is not configured for this app.": "Ứng dụng chưa được cấu hình để dùng Groq.",
            "Add a Groq API key in settings before using Groq.": "Thêm khóa Groq API trong cài đặt trước khi sử dụng Groq.",
            "The Groq API key could not be accessed in Keychain.": "Không thể truy cập khóa Groq API trong Chuỗi khóa.",
            "Groq rejected this API key. Check it in settings.": "Groq từ chối khóa API này. Hãy kiểm tra trong cài đặt.",
            "Could not connect to Groq. Check your internet connection.": "Không thể kết nối với Groq. Hãy kiểm tra kết nối Internet.",
            "Groq API limit or credit reached. Check your Groq account.": "Đã đạt giới hạn hoặc hết tín dụng Groq API. Hãy kiểm tra tài khoản Groq.",
            "Groq could not complete this lookup. Try again later.": "Groq không thể hoàn tất lượt tra này. Hãy thử lại sau.",
            "Groq returned no usable explanation. Try again.": "Groq không trả về giải nghĩa dùng được. Hãy thử lại."
        ]
        guard language == .vietnamese else { return message }
        if let translated = known[message] { return translated }
        if message.hasPrefix("English to "), message.hasSuffix(" is not supported by Apple Translation on this Mac. Your lookup was not sent to another provider.") {
            let name = String(message.dropFirst("English to ".count).dropLast(" is not supported by Apple Translation on this Mac. Your lookup was not sent to another provider.".count))
            return "Apple Translation trên máy Mac này không hỗ trợ dịch từ tiếng Anh sang \(name). Nội dung tra chưa được gửi đến dịch vụ khác."
        }
        if message.hasPrefix("English to "), message.hasSuffix(" is supported, but its language files are not installed. Install them on this Mac, then try again.") {
            let name = String(message.dropFirst("English to ".count).dropLast(" is supported, but its language files are not installed. Install them on this Mac, then try again.".count))
            return "Máy Mac này hỗ trợ dịch từ tiếng Anh sang \(name), nhưng chưa cài dữ liệu ngôn ngữ. Hãy cài trên máy rồi thử lại."
        }
        return message
    }

    public func translationDetail(target: String) -> String {
        choose("Đã dịch trên máy từ tiếng Anh sang \(target).", "Translated on this Mac from English to \(target).")
    }

    public func resultDetail(_ detail: String) -> String {
        let prefix = "Translated on this Mac from English to "
        guard detail.hasPrefix(prefix), detail.hasSuffix(".") else { return detail }
        let target = String(detail.dropFirst(prefix.count).dropLast())
        return translationDetail(target: target)
    }
}
