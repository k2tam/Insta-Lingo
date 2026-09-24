# Ưu tiên xử lý lượt tra trên máy

Ứng dụng dùng xử lý trên máy theo mặc định: Apple Foundation Models cho giải nghĩa theo ngữ cảnh và Apple Translation cho các cặp ngôn ngữ được hỗ trợ. Gemini API là lựa chọn người dùng tự bật và cấu hình bằng khóa API riêng; khi bật, nội dung cần tra và ngữ cảnh được gửi đến Google. Cách này ưu tiên tốc độ và riêng tư trong luồng tra nhanh, đồng thời giữ một đường cloud cho trường hợp người dùng muốn chất lượng hoặc ngôn ngữ khác. Gói Google AI Pro không được coi là quyền sử dụng Gemini API của ứng dụng.

## Consequences

Ứng dụng phải kiểm tra tính sẵn có của model và ngôn ngữ lúc chạy, rồi giải thích rõ khi đường xử lý đã chọn không dùng được. Khóa Gemini API và quota/billing thuộc cấu hình riêng của người dùng.
