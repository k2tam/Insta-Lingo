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
    public var inputAccessibility: String { choose("Từ hoặc cụm cần tra", "Word or short phrase to look up") }
    public var resultLanguage: String { choose("Ngôn ngữ kết quả", "Result language") }
    public var simpleEnglish: String { choose("Tiếng Anh đơn giản", "Simple English") }
    public var local: String { choose("Trên máy", "Local") }
    public var lookup: String { choose("Tra nghĩa", "Look up") }
    public var historyTitle: String { choose("Lịch sử tra", "Lookup history") }
    public var idle: String { choose("Nhập từ hoặc cụm ngắn để xem nghĩa.", "Type a word or short phrase to see its meaning.") }
    public var loading: String { choose("Đang tra trên máy…", "Looking up on this Mac…") }
    public var moreDetail: String { choose("Xem thêm", "More detail") }
    public var storageUnavailable: String { choose("Không thể lưu dữ liệu trên máy. Hãy kiểm tra dung lượng và quyền truy cập rồi thử lại.", "Could not save data on this Mac. Check storage space and permissions, then try again.") }
    public var newContext: String { choose("Ngữ cảnh mới…", "New context…") }
    public var newProfessionalContext: String { choose("Ngữ cảnh chuyên môn mới", "New professional context") }
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
        case "general": generalContext
        case "software-development": softwareContext
        case "swift-ios": swiftContext
        default: customName
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
    public var reviewingOCR: String { choose("Kiểm tra chữ nhận diện", "Review recognized text") }
    public var reviewingSelection: String { choose("Chọn nội dung cần tra", "Choose lookup text") }
    public var lookupPhrase: String { choose("Từ hoặc cụm cần tra", "Word or phrase to look up") }
    public var optionalSelectedSentence: String { choose("Câu ngữ cảnh đã chọn (không bắt buộc)", "Selected context sentence (optional)") }
    public var selectedSentenceHint: String { choose("Câu ngữ cảnh phải nằm trong phần chữ đã chọn và chứa từ cần tra.", "The context sentence must come from the selected text and contain the lookup phrase.") }
    public var useSelectionAsSentence: String { choose("Dùng phần chọn làm câu ngữ cảnh", "Use selection as context sentence") }
    public var recognizedTextAccessibility: String { choose("Chữ nhận diện; sửa hoặc chọn một từ hay cụm", "Recognized text; edit or select a word or phrase") }
    public var useRecognizedText: String { choose("Tra chữ nhận diện", "Look up text") }
    public var useSelectedText: String { choose("Tra phần chữ đã chọn", "Look up selection") }
    public var lookupSelection: String { choose("Tra chữ đang bôi đen", "Look up selected text") }
    public var readingSelection: String { choose("Đang đọc phần chữ đã chọn…", "Reading selected text…") }
    public var accessibilityPermissionNeeded: String { choose("Cần quyền Trợ năng để đọc chữ đã bôi đen. Cấp quyền cho TransAtGlance trong Cài đặt hệ thống → Quyền riêng tư & Bảo mật → Trợ năng, rồi thử lại.", "Accessibility permission is needed to read selected text. Enable TransAtGlance in System Settings → Privacy & Security → Accessibility, then try again.") }
    public var retrySelection: String { choose("Thử đọc lại", "Retry selection") }
    public var selectionUnavailable: String { choose("Không đọc được chữ đang bôi đen trong ứng dụng trước đó. Bạn có thể chọn vùng màn hình để nhận diện chữ.", "The previous app did not provide selected text. You can select a screen region to recognize it.") }
    public var selectRegionInstead: String { choose("Chọn vùng thay thế", "Select region instead") }
    public var gemini: String { "Gemini" }
    public var geminiAPIKey: String { choose("Khóa Gemini API", "Gemini API key") }
    public var enableGemini: String { choose("Bật Gemini", "Enable Gemini") }
    public var saveKey: String { choose("Lưu khóa", "Save key") }
    public var removeKey: String { choose("Xóa khóa", "Remove key") }
    public var geminiDisclosure: String { choose("Khi chọn Gemini, nội dung tra, ngôn ngữ kết quả và ngữ cảnh đã chọn sẽ được gửi đến Google.", "When Gemini is selected, the lookup text, result language, and selected context are sent to Google.") }
    public var lookupSource: String { choose("Nguồn tra nghĩa", "Lookup source") }
    public var apiKeySaved: String { choose("Đã lưu khóa API", "API key saved") }
    public var geminiLoading: String { choose("Đang tra bằng Gemini…", "Looking up with Gemini…") }
    public var localFallbackTitle: String { choose("Tra bằng Gemini?", "Look up with Gemini?") }
    public var localFallbackExplanation: String { choose("Tra trên máy không khả dụng. Nếu tiếp tục, nội dung tra và ngữ cảnh đã chọn sẽ được gửi đến Google. Ứng dụng sẽ nhớ lựa chọn của bạn.", "Local lookup is unavailable. If you continue, the lookup text and selected context will be sent to Google. Your choice will be remembered.") }
    public var useGeminiFallback: String { choose("Dùng Gemini", "Use Gemini") }
    public var declineGeminiFallback: String { choose("Không dùng Gemini", "Do not use Gemini") }
    public var fallbackSetting: String { choose("Khi tra trên máy không khả dụng", "When Local lookup is unavailable") }
    public var fallbackAsk: String { choose("Hỏi tôi", "Ask me") }
    public var fallbackAllow: String { choose("Dùng Gemini", "Use Gemini") }
    public var fallbackDecline: String { choose("Không dùng Gemini", "Do not use Gemini") }

    /// Core and system adapters currently expose localizedDescription as text.
    /// Translate their known messages at the UI boundary; unknown errors remain
    /// visible so the user still gets a useful diagnosis.
    public func errorMessage(_ message: String) -> String {
        let known: [String: String] = [
            "Enter an English word or short phrase to look up.": "Nhập từ hoặc cụm tiếng Anh cần tra.",
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
            "Choose an English word or short phrase from the recognized text.": "Chọn một từ hoặc cụm tiếng Anh trong chữ đã nhận diện.",
            "Choose a phrase and optional sentence from the selected text. The sentence must contain the phrase.": "Chọn từ hoặc cụm cùng câu ngữ cảnh trong phần chữ đã chọn. Câu phải chứa từ hoặc cụm cần tra.",
            "Screen Recording permission is needed to read the region you select. Enable TransAtGlance in System Settings → Privacy & Security → Screen & System Audio Recording, then try again.": "Cần quyền Ghi màn hình để đọc vùng bạn chọn. Bật TransAtGlance trong Cài đặt hệ thống → Quyền riêng tư & Bảo mật → Ghi màn hình & âm thanh hệ thống, rồi thử lại.",
            "Enable Gemini in settings before selecting it for a lookup.": "Bật Gemini trong cài đặt trước khi chọn để tra nghĩa.",
            "Add a Gemini API key in settings before using Gemini.": "Thêm khóa Gemini API trong cài đặt trước khi sử dụng Gemini.",
            "The Gemini API key could not be accessed in Keychain.": "Không thể truy cập khóa Gemini API trong Chuỗi khóa.",
            "Gemini rejected this API key. Check it in settings.": "Gemini từ chối khóa API này. Hãy kiểm tra trong cài đặt.",
            "Could not connect to Gemini. Check your internet connection.": "Không thể kết nối với Gemini. Hãy kiểm tra kết nối Internet.",
            "Gemini API limit or credit reached. Check your Google AI Studio quota.": "Đã đạt giới hạn hoặc hết tín dụng Gemini API. Hãy kiểm tra hạn mức Google AI Studio.",
            "Gemini could not complete this lookup. Try again later.": "Gemini không thể hoàn tất lượt tra này. Hãy thử lại sau.",
            "Gemini returned no usable explanation. Try again.": "Gemini không trả về giải nghĩa dùng được. Hãy thử lại."
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
