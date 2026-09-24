# Spec: Tra nghĩa nhanh từ menu bar trên macOS

## Problem Statement

Khi đọc tài liệu trên Mac, người dùng gặp một từ hoặc cụm tiếng Anh chưa hiểu. Việc chuyển sang tab khác, mở trình duyệt hoặc hỏi một công cụ khác làm đứt mạch đọc. Người dùng cần thấy nghĩa ngắn, đúng ngữ cảnh ngay bên dưới icon trên menu bar, rồi quay lại tài liệu trong một thao tác. Cách lấy chữ phải phù hợp với cả nội dung bôi đen được, nội dung chỉ hiện trên màn hình và trường hợp muốn nhập tay.

## Solution

TransAtGlance là tiện ích menu bar dành cho Mac Apple Silicon chạy macOS mới. Một **lượt tra** bắt đầu từ nhập tay, phần chữ đã bôi đen hoặc **vùng chọn màn hình** được nhận diện bằng OCR. Bảng tra neo dưới icon menu bar hiển thị **kết quả tra** ngắn gồm nghĩa chính, ví dụ theo **ngữ cảnh chuyên môn** và nút mở rộng. Người dùng có thể chọn dịch sang tiếng Việt, ngôn ngữ đích khác khi được hỗ trợ, hoặc nhận **giải nghĩa đơn giản** bằng tiếng Anh. Bảng tự đóng khi quay lại tài liệu và giữ kết quả gần nhất.

Xử lý trên máy là mặc định: Apple Foundation Models hỗ trợ giải nghĩa theo ngữ cảnh, Apple Translation dịch các cặp ngôn ngữ sẵn có. Gemini API là lựa chọn cloud theo từng lượt tra sau khi người dùng tự bật và cấu hình khóa API. Cửa sổ ứng dụng riêng dùng để xem **lịch sử tra**, **mục yêu thích** và cài đặt.

## User Stories

1. Là người đọc tài liệu, tôi muốn mở bảng tra bằng icon menu bar, để không phải chuyển ứng dụng.
2. Là người đọc tài liệu, tôi muốn mở bảng tra bằng phím tắt toàn hệ thống, để bắt đầu lượt tra khi tay đang trên bàn phím.
3. Là người đọc tài liệu, tôi muốn nhập trực tiếp một từ tiếng Anh, để tra khi đã biết cách viết.
4. Là người đọc tài liệu, tôi muốn nhập một cụm tiếng Anh ngắn, để hiểu nghĩa của cả cụm.
5. Là người đọc tài liệu, tôi muốn sửa nội dung cần tra trước khi gửi, để khắc phục chữ nhận diện sai.
6. Là người đọc tài liệu, tôi muốn lấy chữ đang bôi đen trong ứng dụng hiện tại, để khỏi nhập lại.
7. Là người đọc tài liệu, tôi muốn được đề nghị kéo vùng màn hình nếu không đọc được chữ đã bôi đen, để tiếp tục lượt tra.
8. Là người đọc tài liệu, tôi muốn kích hoạt kéo vùng từ bảng tra, để lấy chữ trong nội dung không thể bôi đen.
9. Là người đọc tài liệu, tôi muốn kích hoạt kéo vùng bằng phím tắt, để chọn chữ nhanh khi đang xem tài liệu.
10. Là người đọc tài liệu, tôi muốn con trỏ cho phép kéo khoanh vùng màn hình như thao tác chụp một phần màn hình, để chọn đúng chữ cần tra.
11. Là người dùng nhiều màn hình, tôi muốn kéo vùng trên bất kỳ màn hình nào, để tra chữ ở nơi tài liệu đang hiện.
12. Là người đọc tài liệu toàn màn hình, tôi muốn kéo vùng ngay trong không gian toàn màn hình, để không phải thoát chế độ đọc.
13. Là người đọc tài liệu, tôi muốn bảng tra tạm ẩn trong lúc kéo vùng rồi hiện lại dưới icon, để vùng chọn không bị che.
14. Là người đọc tài liệu, tôi muốn OCR tự bắt đầu lượt tra khi chỉ thấy một từ hoặc cụm ngắn rõ ràng, để giảm thao tác.
15. Là người đọc tài liệu, tôi muốn xem và chỉnh chữ OCR khi vùng có nhiều chữ hoặc kết quả không chắc, để tránh tra sai.
16. Là người đọc tài liệu, tôi muốn chọn một từ hoặc cụm trong chữ OCR dài, để lượt tra vẫn tập trung.
17. Là người đọc tài liệu, tôi muốn tùy ý thêm câu xung quanh trong phạm vi chữ mình đã chọn, để nghĩa phù hợp hơn.
18. Là người chú trọng riêng tư, tôi muốn ứng dụng chỉ đọc chữ tôi đã chọn, để nội dung khác trên màn hình không bị đưa vào lượt tra.
19. Là người đọc tài liệu, tôi muốn tiếng Việt là ngôn ngữ đích mặc định, để hiểu nghĩa nhanh.
20. Là người học tiếng Anh, tôi muốn nhận giải nghĩa đơn giản bằng tiếng Anh, để hiểu từ mới mà vẫn luyện đọc tiếng Anh.
21. Là người đọc tài liệu đa ngôn ngữ, tôi muốn chọn ngôn ngữ đích khác khi có hỗ trợ, để dùng ứng dụng trong nhiều tình huống.
22. Là người đọc tài liệu, tôi muốn ứng dụng nhớ ngôn ngữ đích gần nhất, để không phải chọn lại ở mỗi lượt tra.
23. Là người đọc tài liệu, tôi muốn thấy nghĩa chính và một ví dụ ngắn, để hiểu từ mà không mất thời gian đọc dài.
24. Là người muốn hiểu sâu hơn, tôi muốn mở rộng kết quả tra, để xem phần giải thích bổ sung khi cần.
25. Là lập trình viên, tôi muốn chọn ngữ cảnh General, Software Development hoặc Swift/iOS, để nhận đúng nghĩa của thuật ngữ.
26. Là lập trình viên, tôi muốn tạo ngữ cảnh chuyên môn bằng tên và mô tả ngắn, để dùng cho lĩnh vực riêng của mình.
27. Là người đọc tài liệu, tôi muốn đổi ngữ cảnh ngay trong bảng tra, để thử nghĩa khác mà không rời tài liệu.
28. Là người đọc tài liệu, tôi muốn ví dụ phản ánh ngữ cảnh đã chọn, để nhận ra cách dùng thực tế.
29. Là người đọc tài liệu, tôi muốn thấy trạng thái đang xử lý và lỗi rõ ràng trong bảng tra, để biết lượt tra đang diễn ra hay cần sửa gì.
30. Là người đọc tài liệu, tôi muốn biết khi model trên máy hoặc cặp ngôn ngữ không sẵn có, để chọn cách tra phù hợp.
31. Là người chú trọng riêng tư, tôi muốn Local là lựa chọn mặc định, để lượt tra bình thường được xử lý trên máy.
32. Là người có khóa Gemini API, tôi muốn bật Gemini trong cài đặt, để có thêm nguồn xử lý khi cần.
33. Là người dùng Gemini, tôi muốn chọn Local hoặc Gemini cho từng lượt tra ngay trong bảng, để kiểm soát nguồn xử lý.
34. Là người dùng Gemini, tôi muốn được thông báo rõ rằng chữ đã chọn và ngữ cảnh sẽ gửi đến Google khi bật Gemini, để chủ động với dữ liệu của mình.
35. Là người dùng Gemini, tôi muốn ứng dụng nhớ quyết định fallback sau khi hỏi một lần khi Local không dùng được, để không bị hỏi lại liên tục.
36. Là người dùng Gemini, tôi muốn thấy lỗi khóa, mạng hoặc giới hạn sử dụng dễ hiểu, để biết vì sao lượt tra không hoàn tất.
37. Là người đọc tài liệu, tôi muốn bảng tra tự đóng khi bấm lại tài liệu, để không che nội dung đang đọc.
38. Là người đọc tài liệu, tôi muốn mở lại bảng tra và thấy kết quả gần nhất, để đọc tiếp mà không tra lại.
39. Là người muốn ôn từ, tôi muốn các lượt tra thành công được lưu tự động khi bật lịch sử, để tìm lại sau.
40. Là người muốn ôn từ, tôi muốn mở cửa sổ ứng dụng riêng để tìm trong lịch sử tra, để không làm bảng tra nhanh trở nên cồng kềnh.
41. Là người muốn ôn từ, tôi muốn mở lại nghĩa và ví dụ của một lượt tra cũ, để nhớ cách dùng.
42. Là người chú trọng riêng tư, tôi muốn tắt lưu lịch sử hoặc xóa lịch sử, để kiểm soát dữ liệu lưu trên máy.
43. Là người muốn giữ từ quan trọng, tôi muốn đánh dấu mục yêu thích cùng nghĩa, ngôn ngữ đích và ngữ cảnh, để xem lại đúng cách mình đã hiểu.
44. Là người học nhiều lĩnh vực, tôi muốn cùng một từ có thể có nhiều mục yêu thích theo ngữ cảnh khác nhau, để không mất các nghĩa chuyên môn.
45. Là người muốn ôn từ, tôi muốn tìm và mở mục yêu thích trong cửa sổ ứng dụng, để xem lại nhanh.
46. Là người muốn dọn dữ liệu, tôi muốn xóa lịch sử mà vẫn giữ mục yêu thích, để không mất các từ đã chọn giữ lại.
47. Là người chú trọng riêng tư, tôi muốn ảnh vùng chọn bị bỏ sau OCR và không nằm trong lịch sử, để không lưu hình tài liệu ngoài ý muốn.
48. Là người dùng tiếng Việt hoặc tiếng Anh, tôi muốn chọn ngôn ngữ giao diện phù hợp, để đọc các điều khiển và lỗi dễ dàng.
49. Là người dùng Mac, tôi muốn tùy chỉnh phím tắt và được báo khi phím tắt không dùng được, để tránh xung đột với công việc hiện tại.
50. Là người dùng Mac, tôi muốn tùy chọn mở tiện ích cùng macOS với trạng thái mặc định tắt, để quyết định khi nào ứng dụng chạy nền.

## Implementation Decisions

- Bản đầu dành cho dùng riêng trên Apple Silicon và macOS mới; nguồn của nội dung cần tra là tiếng Anh, đơn vị tra là từ hoặc cụm ngắn.
- Giao diện tra nhanh là một bảng neo dưới icon menu bar theo cảm giác menu hệ thống macOS. Ô nhập, lấy chữ bôi đen, kéo vùng, chọn ngôn ngữ, chọn ngữ cảnh, chọn nguồn xử lý, trạng thái và kết quả đều ở cùng bảng.
- Bảng tự đóng khi mất tương tác và giữ kết quả gần nhất trong phiên ứng dụng. Cửa sổ ứng dụng riêng chỉ phục vụ lịch sử tra, mục yêu thích và cài đặt.
- Có ba đường lấy nội dung cần tra: nhập tay, đọc chữ bôi đen qua Accessibility, và nhận diện từ vùng chọn màn hình qua OCR. Nếu Accessibility không đọc được, hướng người dùng sang kéo vùng; không tự sao chép qua clipboard.
- Vùng chọn hỗ trợ màn hình chính, màn hình phụ và tài liệu toàn màn hình. Bảng tra ẩn trong lúc chọn; sau OCR bảng trở lại vị trí neo.
- OCR tự tra khi nhận một từ hoặc cụm ngắn đủ rõ. Khi OCR nhiều chữ hoặc chưa chắc, người dùng sửa hoặc chọn nội dung cần tra trước khi gửi. Ảnh vùng chọn chỉ tồn tại trong quá trình OCR.
- Câu ngữ cảnh chỉ đến từ nội dung mà người dùng tự chọn. Ứng dụng không tự đọc văn bản bên ngoài phần đã chọn.
- Kết quả tra có nghĩa chính, một ví dụ theo ngữ cảnh, phần mở rộng tùy chọn và trạng thái tải/lỗi rõ ràng. Ngôn ngữ đích mặc định là tiếng Việt, hỗ trợ giải nghĩa đơn giản English → English và các ngôn ngữ khác khi nguồn xử lý hỗ trợ; nhớ lựa chọn gần nhất.
- Preset ngữ cảnh chuyên môn ban đầu là General, Software Development và Swift/iOS. Preset tự tạo gồm tên và mô tả ngắn.
- Theo ADR xử lý trên máy, Local là mặc định: Apple Foundation Models tạo giải nghĩa theo ngữ cảnh; Apple Translation dịch khi cặp ngôn ngữ được hỗ trợ. Kiểm tra tính sẵn có của model và cặp ngôn ngữ lúc chạy, rồi thông báo rõ khi không thể dùng.
- Gemini API là tùy chọn cloud do người dùng bật và cung cấp khóa API riêng. Gói Google AI Pro không được giả định là quyền truy cập hoặc quota Gemini API. Khóa được lưu trong kho thông tin bảo mật của hệ điều hành, tách khỏi lịch sử.
- Khi Gemini đã bật, chọn Gemini cho một lượt tra cho phép gửi nội dung cần tra và ngữ cảnh đã chọn đến Google. Nếu Local không khả dụng, ứng dụng hỏi một lần trước khi ghi nhớ tùy chọn fallback; không âm thầm chuyển nguồn xử lý.
- Lượt tra thành công được lưu trên máy nếu tùy chọn lịch sử bật. Lịch sử có tìm kiếm, mở lại kết quả và xóa. Mục yêu thích lưu riêng để vẫn còn sau khi xóa lịch sử; khóa phân biệt cùng từ theo ngôn ngữ đích và ngữ cảnh.
- Phím tắt toàn hệ thống mở bảng tra và kích hoạt các đường lấy chữ; người dùng chỉnh được. Mở cùng macOS là tùy chọn và mặc định tắt.
- Giao diện có tiếng Việt và tiếng Anh. Quyền Accessibility và ghi màn hình được xin đúng lúc người dùng dùng tính năng cần quyền, kèm đường quay lại sau khi cấp quyền.
- Phần điều phối lượt tra là ranh giới hành vi chính: nhận nội dung từ ba nguồn, áp dụng ngôn ngữ/ngữ cảnh/nguồn xử lý, trả trạng thái và kết quả cho bảng tra, rồi lưu kết quả thành công. Các tích hợp macOS và model được nối ở rìa để có thể thay bằng bản giả trong kiểm thử.

## Testing Decisions

- Kiểm thử hành vi quan sát được: chữ nào được gửi, bảng hiện trạng thái nào, kết quả nào được lưu, lỗi nào được báo và người dùng có thể trở lại tài liệu ra sao. Tránh kiểm thử chi tiết cấu trúc nội bộ hay prompt cố định của model.
- Ranh giới kiểm thử chính là luồng lượt tra qua bảng menu bar và phần điều phối lượt tra. Các bộ lấy chữ, OCR, dịch/giải nghĩa và lưu dữ liệu được thay bằng bản giả có kiểm soát để kiểm thử từ thao tác đầu đến kết quả.
- Bao phủ cả ba nguồn nhập, OCR tự tra/chờ sửa, Accessibility thất bại chuyển sang kéo vùng, đổi ngôn ngữ/ngữ cảnh, Local/Gemini, trạng thái chờ và lỗi, đóng/mở lại bảng, lưu lịch sử và mục yêu thích.
- Kiểm tra trực tiếp trên Mac đối với kéo vùng trên nhiều màn hình/toàn màn hình, quyền Accessibility/ghi màn hình, OCR thực tế, neo bảng dưới menu bar, phím tắt toàn hệ thống, Foundation Models và Translation khi có hoặc thiếu khả dụng.
- Kiểm tra riêng hành vi dữ liệu bền vững sau khi thoát/mở ứng dụng: lịch sử, mục yêu thích, xóa lịch sử nhưng giữ mục yêu thích, tùy chọn lưu, ngôn ngữ đích và cài đặt.
- Kiểm tra rằng ảnh vùng chọn không được ghi vào lịch sử, và Gemini chỉ nhận chữ/ngữ cảnh đã chọn sau khi người dùng bật đường cloud.
- Repo hiện chưa có mã ứng dụng hoặc bộ kiểm thử để làm mẫu. Các kiểm thử đầu tiên nên thiết lập ranh giới hành vi trên, rồi bổ sung kiểm tra tích hợp macOS cho những phần không thể mô phỏng trung thực.

## Out of Scope

- Bản phát hành công khai, hỗ trợ Intel hoặc macOS cũ.
- Tra cả đoạn văn dài, dịch toàn trang hoặc giải thích nhiều thuật ngữ trong một lượt tra.
- Tự đọc nội dung ngoài vùng người dùng đã chọn, lưu ảnh chụp màn hình, hoặc dùng clipboard làm đường dự phòng âm thầm.
- Đồng bộ dữ liệu giữa thiết bị, tài khoản, chia sẻ từ vựng, flashcard hoặc nhắc ôn theo lịch.
- Coi gói Google AI Pro là khóa API hoặc quota cho Gemini API.

## Further Notes

- Mẫu giao diện được chốt là bảng mở rộng neo dưới icon menu bar giống cách menu Battery của macOS hiện ra; đây là tham chiếu cho vị trí và nhịp thao tác, không yêu cầu sao chép thiết kế Battery.
- Nếu cặp ngôn ngữ hoặc model local không sẵn, ứng dụng cần nêu lý do và lựa chọn khả dụng theo cài đặt hiện tại. Bản đầu không cam kết mọi ngôn ngữ đích đều có dịch local.
- Ưu tiên độ nhanh và sự liền mạch trong lúc đọc tài liệu: từ kích hoạt, lấy chữ, xem nghĩa đến trở lại trang đều diễn ra mà không cần mở trình duyệt.
