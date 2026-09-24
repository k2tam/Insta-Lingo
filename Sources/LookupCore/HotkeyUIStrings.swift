public extension UIStrings {
    var hotkeysTitle: String { language == .vietnamese ? "Phím tắt toàn hệ thống" : "Global shortcuts" }
    var hotkeyOpenPanel: String { language == .vietnamese ? "Mở bảng tra" : "Open lookup panel" }
    var hotkeySelectedText: String { language == .vietnamese ? "Tra chữ bôi đen" : "Look up selected text" }
    var hotkeyScreenRegion: String { language == .vietnamese ? "Chọn vùng màn hình" : "Select screen region" }
    var hotkeyChange: String { language == .vietnamese ? "Đổi" : "Change" }
    var hotkeyRecording: String { language == .vietnamese ? "Nhấn tổ hợp phím…" : "Press a key combination…" }
    var hotkeyCancelHint: String { language == .vietnamese ? "Escape để hủy. Cần ⌘, ⌥ hoặc ⌃." : "Escape to cancel. Include ⌘, ⌥, or ⌃." }
    var hotkeyInvalid: String { language == .vietnamese ? "Tổ hợp này cần ⌘, ⌥ hoặc ⌃ cùng một phím." : "Use ⌘, ⌥, or ⌃ with another key." }
    var hotkeyConflict: String { language == .vietnamese ? "Tổ hợp phím này đã được dùng hoặc macOS không thể đăng ký. Tổ hợp cũ vẫn hoạt động." : "This shortcut is in use or macOS could not register it. The previous shortcut still works." }
    var hotkeyRegistrationFailed: String { language == .vietnamese ? "Không đăng ký được phím tắt trên Mac này. Hãy chọn tổ hợp khác." : "Could not register this shortcut on this Mac. Choose another combination." }

    func hotkeyActionName(_ action: HotkeyAction) -> String {
        switch action {
        case .openPanel: hotkeyOpenPanel
        case .selectedText: hotkeySelectedText
        case .screenRegion: hotkeyScreenRegion
        }
    }
}
