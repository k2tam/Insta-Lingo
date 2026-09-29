# Ưu tiên Groq cho lượt tra

Ứng dụng dùng model `openai/gpt-oss-120b` qua Groq theo mặc định để giải nghĩa và dịch theo ngữ cảnh. Khi chọn Groq, nội dung cần tra, ngôn ngữ kết quả và ngữ cảnh chuyên môn được gửi đến Groq. Khóa API do người dùng cung cấp được lưu trong macOS Keychain. Apple Foundation Models và Apple Translation vẫn là lựa chọn xử lý trên máy.

Tra nhanh nghĩa (nhấp đúp từ trong kết quả) luôn dùng `openai/gpt-oss-20b`, và mức reasoning mặc định là `low`.

## Consequences

Người dùng phải thêm Groq API key trước khi tra bằng Groq. Ứng dụng phải công khai dữ liệu nào được gửi lên cloud và báo rõ lỗi khóa, mạng, hạn mức hoặc kết quả không hợp lệ. Với nguồn Apple, ứng dụng kiểm tra tính sẵn có của model và ngôn ngữ lúc chạy rồi nêu rõ lý do khi không thể dùng. Ứng dụng không âm thầm chuyển đổi giữa Groq và Apple.
