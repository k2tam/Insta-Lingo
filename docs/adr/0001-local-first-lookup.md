# Ưu tiên Groq cho lượt tra

Ứng dụng dùng model `openai/gpt-oss-120b` qua Groq theo mặc định để giải nghĩa và dịch theo ngữ cảnh. Khi chọn Groq, nội dung cần tra, ngôn ngữ kết quả và ngữ cảnh chuyên môn được gửi đến Groq. Khóa API do người dùng cung cấp được lưu trong macOS Keychain. Apple Foundation Models và Apple Translation vẫn là lựa chọn xử lý trên máy.

Tra nhanh nghĩa (nhấp đúp từ trong kết quả) luôn dùng `openai/gpt-oss-20b`, và mức reasoning mặc định là `low`.

## Consequences

Người dùng phải thêm Groq API key trước khi tra bằng Groq. Ứng dụng phải công khai dữ liệu nào được gửi lên cloud và báo rõ lỗi khóa, mạng, hạn mức hoặc kết quả không hợp lệ. Với nguồn Apple, ứng dụng kiểm tra tính sẵn có của model và ngôn ngữ lúc chạy rồi nêu rõ lý do khi không thể dùng. Ứng dụng không âm thầm chuyển đổi giữa Groq và Apple.

## Cập nhật: khóa mặc định qua proxy

Khóa Groq của người dùng giờ là tùy chọn. Nếu chưa có khóa riêng, ứng dụng gửi yêu cầu đến proxy (`proxy/`, Cloudflare Worker) giữ khóa mặc định dưới dạng secret; ứng dụng không chứa khóa nào. Nội dung tra vì vậy đi qua proxy này (không được ghi log) trước khi đến Groq, và có giới hạn theo lượt. Thêm khóa riêng để gọi thẳng Groq không giới hạn.

## Cập nhật: mô hình tích hợp và mô hình tùy chỉnh

Mô hình tích hợp (GPT-OSS 120B/20B qua proxy, miễn phí nhưng có giới hạn) là mặc định; ứng dụng không còn mục nhập khóa Groq riêng. Thay vào đó, người dùng có thể thêm bất kỳ endpoint tương thích OpenAI nào (OpenAI, Groq, OpenRouter, DeepSeek, Ollama, LM Studio…) làm mô hình tùy chỉnh, gồm tên, base URL, model ID và khóa API tùy chọn lưu trong Keychain, rồi chọn một mô hình đang dùng. Khi dùng mô hình tùy chỉnh, nội dung tra, ngôn ngữ kết quả và ngữ cảnh được gửi thẳng đến host đó, không qua proxy; cài đặt hiển thị rõ host nhận dữ liệu. `http://` chỉ được chấp nhận cho localhost, 127.0.0.1 và `.local`. Khóa Groq đã lưu từ phiên bản trước là khóa mặc định của ứng dụng (nay nằm ở proxy) nên được xóa khỏi Keychain; mô hình tích hợp qua proxy luôn là mặc định và người dùng không chỉnh khóa này.
