# GymFlow — Flutter app

App có upload avatar/quà/PT, quên mật khẩu bằng mã email và QR admin tự đổi mỗi giờ. Chủ project cập nhật Supabase theo [UPDATES_003.md](../supabase/UPDATES_003.md). Các ô mật khẩu có nút hiện/ẩn; thẻ hồ sơ tách riêng; mã QR gồm 10 ký tự in hoa/số.

Flutter dùng REST API Express trong [../backend](../backend), Express kết nối PostgreSQL và Auth của Supabase. Giữ 5 tab Trang chủ, GymPoint, Đổi thưởng, Dịch vụ, Tài khoản cùng theme Orange Energy, nền warm white và component card/button chung.

## Chạy với API chung (thành viên chỉ cần Flutter)

URL mặc định hiện trỏ đến Supabase Edge Function `gymflow-api`. Nhóm trưởng cập nhật database và deploy API mới theo [hướng dẫn kích hoạt các luồng nghiệp vụ](../supabase/WORKFLOWS.md). Khi function đã hoạt động, thành viên chỉ cần Flutter/Android toolchain và Internet.

Sau khi bước trên hoàn tất, các thành viên chỉ cần Flutter/Android toolchain và Internet. Mở terminal trong thư mục `tec550030`:

```powershell
flutter pub get
flutter run
```

Không chạy Node, không tạo `.env`, không cần IP LAN. Điện thoại thật bật USB debugging, nối USB và chọn thiết bị bằng `flutter run -d DEVICE_ID`; máy và điện thoại không cần cùng mạng. Cấu hình Run and Debug **GymFlow** trong VS Code cũng dùng URL mặc định.

## Chạy backend local (dành cho phát triển API)

Thiết lập schema, seed và `.env` theo [hướng dẫn backend](../backend/README.md). Giữ terminal backend mở:

```powershell
cd D:\TEC550030\backend
npm.cmd ci
npm.cmd run dev
```

Terminal khác, Android Emulator:

```powershell
cd D:\TEC550030\tec550030
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Điện thoại thật: thay base URL bằng IPv4 LAN của máy chạy Express, ví dụ `http://192.168.1.10:3000`. Hai thiết bị cùng mạng; Windows Firewall cho phép Node/port 3000. Android debug cho phép HTTP local; bản release cần API HTTPS. Flutter không đọc file `backend/.env`; địa chỉ server được cấu hình qua `--dart-define`.

Nếu app đang mở từ bản giao diện mẫu, **hot restart hoặc chạy lại app**. Đăng nhập bằng tài khoản Supabase Auth thật; đăng ký mới trong app nếu chưa có tài khoản. Khi Confirm email bật, xác nhận email trước login.

## UI đã nối API

| Màn hình | Nội dung từ API |
| --- | --- |
| Đăng ký/đăng nhập | Form validation, gọi Auth thật, lưu session; giải thích xác nhận email; báo lỗi khi bị từ chối |
| Trang chủ | Tên hội viên, balance, gói hiện tại và hạn sử dụng, danh mục quà; shortcut sang các tab |
| GymPoint | Tổng ledger và lịch sử điểm có dấu, lý do, loại giao dịch, thời gian; tải thêm 20 giao dịch mỗi lần |
| Đổi thưởng | Tất cả quà active, ảnh/biểu tượng thay thế, point cost, stock và trạng thái hết quà |
| Chi tiết quà | Request detail mới, hiển thị mô tả đầy đủ, điểm và stock hiện tại |
| Dịch vụ | Tab gói: giá VND, số ngày, điểm/QR, mô tả; tab PT: tên, ảnh, chuyên môn, kinh nghiệm |
| Chi tiết gói/PT | Gọi API detail riêng, hiển thị quyền lợi và hồ sơ đầy đủ |
| Tài khoản | Tên, email, ngày tham gia, balance, gói và hạn sử dụng; shortcut lịch sử điểm; logout |

Tất cả danh sách có loading, lỗi có nút thử lại, empty state và kéo refresh. Catalogue tự tải qua các trang nếu vượt 100 bản ghi. Không gán điểm, hồ sơ hoặc danh sách giả khi API lỗi.

Auth tự khôi phục phiên khi mở app, tự refresh khi access token bị từ chối; refresh bị từ chối thì về login. Lỗi mạng/5xx giữ phiên và cho thử lại. Logout xóa cả access và refresh token; response refresh đến trễ không khôi phục phiên đã đăng xuất.

## Các luồng nghiệp vụ đã tích hợp

Trang chủ có QR check-in/check-out, người đang tập và biểu đồ từng giờ. Chi tiết quà có đổi quà; chi tiết gói có gửi đơn chờ thanh toán tại quầy/duyệt; chi tiết PT có chọn ngày/giờ trống và đặt lịch. Tài khoản có chỉnh sửa tên và Hoạt động của tôi (buổi tập, đơn gói, mã nhận quà, lịch PT/hủy lịch), có tải thêm lịch sử. Đăng ký yêu cầu nhập lại mật khẩu khớp trước khi gửi API.

Admin có tạo/thu hồi QR, duyệt/từ chối đơn, xác nhận giao quà, thêm/sửa/ẩn/mở lại danh mục quà/gói/PT. Cần migration `002_workflows.sql` và deploy lại function; cách cấp ADMIN, danh sách API và luồng kiểm tra xem [WORKFLOWS.md](../supabase/WORKFLOWS.md). Camera và nhận thanh toán/giao quà cần kiểm tra trên thiết bị thật.

## Kiểm tra

```powershell
cd D:\TEC550030\tec550030
flutter analyze
flutter test
```

Test HTTP/auth và widget dùng response fixture ở biên HTTP, không tạo user hoặc sửa dữ liệu Supabase thật. Bao gồm login lỗi/thành công, xác nhận email, session refresh/expiry, logout trong lúc refresh, list/detail, lỗi/retry, lịch sử nhiều trang và màn hình 320px với chữ lớn.

Kiểm tra thủ công với server thật:

1. `GET /health` báo connected; `GET /rewards` trả dữ liệu database.
2. Đăng ký bằng email của bạn, xác nhận email nếu được yêu cầu, rồi đăng nhập.
3. Kiểm tra Home/Tài khoản đúng tên/email; ví điểm 0 và lịch sử trống khi chưa có giao dịch.
4. Mở Đổi thưởng, Dịch vụ và các trang chi tiết.
5. Sửa tên/stock/giá trong Supabase Table Editor, kéo refresh để thấy thay đổi.
6. Tắt backend và refresh: app báo lỗi có thể thử lại, không thay bằng dữ liệu mẫu.
7. Đăng xuất: về login; mở lại app không vào Home bằng phiên cũ.

Cấu trúc chính: `lib/core/api` quản lý HTTP/session; `models` mapping dữ liệu; `services` gọi API; `screens` hiển thị; `widgets` là component dùng chung. Chi tiết schema/ERD và API ở [backend/README.md](../backend/README.md).
