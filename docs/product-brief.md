# Insta Lingo — bản thiết kế đã trao đổi

## Mục tiêu

Giúp người đang đọc tài liệu trên macOS hiểu nhanh một từ hoặc cụm tiếng Anh mà không phải chuyển sang trình duyệt. Bản đầu dành cho Mac Apple Silicon chạy macOS mới; ưu tiên máy MacBook Air M1 hiện tại.

## Luồng tra nhanh

- App sống trên menu bar. Bấm icon hoặc dùng phím tắt toàn hệ thống để mở bảng tra.
- Có ba nguồn chữ: nhập tay, đọc phần chữ đã bôi đen trong ứng dụng đang dùng, hoặc kéo khoanh vùng màn hình rồi OCR. Nếu ứng dụng không cung cấp chữ đã bôi đen, đề nghị kéo vùng.
- Thao tác kéo vùng hoạt động trên màn hình chính, màn hình phụ và khi tài liệu ở full screen. Nếu OCR nhận được một từ/cụm ngắn rõ ràng, app tra ngay; nếu vùng có nhiều chữ hoặc kết quả không chắc, cho sửa/chọn nội dung cần tra trước.
- Lượt tra chỉ dùng ngữ cảnh chuyên môn đang chọn. App không tự lấy nội dung bên ngoài vùng đã chọn.
- Bảng tra neo ở menu bar, tự đóng khi người dùng quay lại tài liệu và giữ kết quả gần nhất để mở lại.

## Kết quả và lựa chọn

- Nguồn chính ở bản đầu là tiếng Anh. Đích mặc định là tiếng Việt; có English → English để giải nghĩa bằng tiếng Anh dễ hiểu và có thể chọn thêm ngôn ngữ đích. App nhớ ngôn ngữ gần nhất.
- Kết quả gọn: nghĩa chính, một ví dụ phù hợp ngữ cảnh và nút mở rộng.
- Preset đầu tiên: General, Software Development, Swift/iOS. Người dùng có thể tạo preset bằng tên và mô tả ngắn.
- Groq chạy `openai/gpt-oss-120b` là nguồn mặc định để giải nghĩa và dịch theo ngữ cảnh. Người dùng tự cung cấp API key, được lưu trong macOS Keychain. Apple Foundation Models và Apple Translation là nguồn xử lý trên máy thay thế.
- Người dùng có thể chọn Groq hoặc Apple ngay trong bảng tra cho từng lượt; lựa chọn mặc định là Groq.

## Xem lại

- Cửa sổ ứng dụng riêng hiển thị lịch sử và danh sách mục yêu thích; có tìm kiếm và mở lại nghĩa, ví dụ. Bản đầu chưa cần flashcard hoặc lịch nhắc ôn.
- Mọi lượt tra thành công được lưu tự động nếu tùy chọn lưu lịch sử đang bật. Người dùng có thể tắt lưu hoặc xóa lịch sử. Xóa lịch sử không xóa mục yêu thích.
- Dữ liệu chỉ lưu trên máy ở bản đầu. Có tùy chọn mở app cùng macOS, mặc định tắt.
- Ảnh vùng chụp chỉ tồn tại trong lúc OCR. Lịch sử lưu chữ đã nhận diện và kết quả tra, không lưu ảnh.
- Giao diện có tiếng Việt và tiếng Anh.
- Cùng một từ có thể có nhiều mục yêu thích theo ngữ cảnh chuyên môn khác nhau.

## Tiêu chí kiểm tra bản đầu

- Từ một trang tài liệu đang mở, người dùng có thể kích hoạt kéo vùng, tra một từ/cụm, đọc nghĩa và quay lại trang mà không phải mở trình duyệt.
- Từ tiếng Anh có thể được giải nghĩa bằng tiếng Anh đơn giản hoặc dịch sang tiếng Việt; app hiển thị rõ khi Groq hoặc nguồn Apple không sẵn.
- Từ/cụm có thể được tra qua chữ bôi đen, nhập tay và OCR; đường bôi đen thất bại dẫn sang kéo vùng.
- Lịch sử và mục yêu thích tồn tại sau khi thoát app; xóa lịch sử không xóa mục yêu thích.
- Giao diện chuyển được giữa tiếng Việt và tiếng Anh; khóa Groq được lưu riêng với dữ liệu lịch sử.
