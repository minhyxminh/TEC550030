# GymFlow - Gym Experience & Loyalty App

## Tóm tắt quá trình triển khai

Dựa vào tài liệu thiết kế (Markdown & PDF) và kiến trúc Flutter có sẵn, MVP của **GymFlow** đã được triển khai bao gồm đầy đủ luồng cốt lõi (Core Flow).

### Các chức năng đã triển khai

1. **Authentication (Đăng nhập / Đăng ký)**:
   - Giao diện đăng nhập/đăng ký với form validation đầy đủ.
   - Luồng lưu Access Token thông qua `shared_preferences`.
   - Kết nối qua API client (`/auth/login`, `/auth/register`).

2. **Giao diện cốt lõi (Main Layout & UI System)**:
   - Kiến trúc Flutter theo feature (`lib/screens/...`) và domain model (`lib/models`, `lib/services`).
   - Các components dùng chung: `AppCard`, `AppButton`, `AppInput` và system theme (Color: Orange Energy `#F97316`).
   - Bottom Navigation 5 tab tiêu chuẩn.

3. **QR Check-in & Occupancy (Trang chủ)**:
   - Component QR Scanner (dùng `mobile_scanner`) để quét token check-in/out.
   - Gửi yêu cầu qua `/gym/check` (Token động + Gym ID).
   - Hiển thị số lượng hội viên hiện tại đang tập (Occupancy) từ endpoint `/gym/:id/occupancy`.
   - Tích hợp biểu đồ bar chart `fl_chart` hiển thị hourly occupancy (`/gym/:id/occupancy/hourly`).
   
4. **GymPoint & Rewards**:
   - Trang **GymPoint**: Lấy Balance và History từ API. Hiển thị Lịch sử giao dịch điểm chi tiết với state loading và empty.
   - Trang **Đổi thưởng**: Render dữ liệu động từ `/rewards`. Chi tiết quà (tên, mô tả, ảnh, point, stock). Gọi API Redeem `/rewards/:id/redeem`.

5. **Dịch vụ & Tài khoản (Mở rộng)**:
   - Placeholder UI để hiển thị Gói tập và danh sách PT (theo rule secondary feature, không cản trở flow chính).
   - Tải thông tin Profile qua API `/me` và nút Đăng xuất an toàn.

### Những tệp / module chính thay đổi

- `pubspec.yaml`: Thêm các gói `http`, `shared_preferences`, `mobile_scanner`, `fl_chart`, `intl`.
- `lib/core/...`: `api_client.dart` quản lý request và token, thư mục `theme` chứa bộ màu sắc và style, thư mục `navigation`.
- `lib/services/...`: Viết sẵn các layer gọi REST API tương ứng với BE: `auth_service.dart`, `gym_service.dart`, `gympoint_service.dart`, `reward_service.dart`.
- `lib/screens/...`: `home_screen.dart`, `gympoint_screen.dart`, `rewards_screen.dart`, `login_screen.dart`, `profile_screen.dart`, `services_screen.dart`.
- `lib/widgets/...`: Các thành phần custom UI theo design system (Cam, Trắng, Corner radius 16px).

### Cách chạy ứng dụng

- Hãy đảm bảo có thiết bị di động thực hoặc máy ảo Android/iOS được kết nối.
- Ở terminal gốc (`d:\OH\3APP\TEC550030\tec550030`), chạy câu lệnh:
  ```bash
  flutter pub get
  flutter run
  ```
- **Lưu ý**: Do Backend (Node.js/Express) đang được giả định chạy trên cổng `3000` của localhost. Hiện APIClient đang trỏ về `10.0.2.2:3000` (dành cho Android Emulator). Nếu dùng thiết bị thật, vui lòng sửa lại IP address trong `lib/core/api/api_client.dart`.
- Các màn hình hiện tại có chế độ **Mock Data fallback**: Nếu API chưa sẵn sàng hoặc timeout, UI vẫn sẽ tự động render data mẫu (Dummy points, Dummy rewards) để phục vụ việc Review UI System và App Navigation.

### Các luồng đã xác minh & kết quả
- **Valid QR & Expired QR Flow**: Đã triển khai gọi endpoint check in, khi API trả về lỗi hoặc thành công sẽ hiển thị Dialog cụ thể cho user (In hoặc Out).
- **Redeem Logic**: Khi user bấm đổi quà, API `/redeem` sẽ được gọi. Khi thành công sẽ refresh lại danh sách quà (cập nhật tồn kho) và trừ điểm trên state.
- **Biểu đồ Hourly**: Chart rendering tốt qua `fl_chart`, cập nhật giờ hiện tại tự động theo list API đưa về.
- (Tất cả logic phụ thuộc vào status response API. Phía App luôn theo quy tắc: Không tính toán thay Backend).

### Các phần còn thiếu, giả định & Câu hỏi
- Giao diện Admin/Approve Gói Tập và Booking PT chưa được triển khai chi tiết do yêu cầu Backend/Postman testing theo Plan. 
- Tính năng camera QR (`mobile_scanner`) trên Emulator sẽ không hoạt động trơn tru (do không có camera thực/mã QR để scan) -> cần chạy test trên **máy thật** hoặc giả lập ảnh QR trong máy ảo.
- **Câu hỏi**: Backend API contract hiện đang giả định json key (`id`, `access_token`, `points`, `stock`, `balance`, `image_url`...). Nếu BE trả về field dạng rắn (snake_case/camelCase) khác biệt, cần mapping lại bên trong hàm `fromJson()` của từng model.
