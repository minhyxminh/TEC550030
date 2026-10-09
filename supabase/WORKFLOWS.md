# Kích hoạt API và UI GymFlow

**Cập nhật mới:** QR lưu lại và tự đổi mỗi giờ, upload ảnh, quên mật khẩu. Với database đã có 001/002, làm theo [UPDATES_003.md](UPDATES_003.md) để áp dụng 003 và cấu hình Cron/email.

Code đã bổ sung check-in/check-out, thống kê phòng tập, đổi quà, đơn gói tập, lịch PT, lịch sử hoạt động và quản trị. Không cần thêm secret/service_role vào Flutter hoặc backend: các RPC lấy danh tính từ JWT và kiểm tra quyền trong database.

## 1. Cập nhật database một lần

Trong Supabase project `resjlmqdtxubcbdpvtds`, mở **SQL Editor → New query**, dán toàn bộ `supabase/migrations/002_workflows.sql`, chọn **Run**. File này chạy sau `001_initial_schema.sql`; không chạy lại file 001 trên database đã có bảng. Migration 002 giữ dữ liệu đang có và có thể chạy lại để cập nhật functions.

Các RPC dùng transaction và row lock cho cộng/trừ điểm, tồn kho và duyệt đơn. Mỗi tài khoản/QR chỉ cộng điểm một lần. Đổi quà, gửi đơn và đặt lịch có `idempotency_key` để gửi lại sau lỗi mạng không tạo thêm giao dịch. RLS vẫn bật; quyền ghi trực tiếp vẫn bị chặn. Cách đặt search_path và giới hạn execute theo [hướng dẫn Database Functions của Supabase](https://supabase.com/docs/guides/database/functions).

## 2. Cập nhật API đã deploy

File `supabase/functions/gymflow-api/index.ts` đã được build lại với API mới. Vào **Edge Functions → gymflow-api → Code**, thay nội dung bằng file mới, **Deploy updates**. Giữ cấu hình **Verify JWT tắt** ở gateway; API tự kiểm tra JWT với Supabase Auth, và RPC kiểm tra `auth.uid()`/vai trò. Chi tiết lần deploy đầu: [SHARED_API.md](SHARED_API.md).

Nếu sửa backend sau này, chạy `npm.cmd run build:edge` trong `backend` rồi deploy lại file được tạo. Sửa source `backend/src/app.js`, không sửa tay file generated.

URL API chung đã nằm trong `tec550030/lib/core/api/shared_api_config.dart`. Sau khi deploy, các thành viên chạy trong thư mục Flutter:

```powershell
flutter pub get
flutter run
```

Với API chung, không cần giữ Node trên máy. Nếu kiểm thử backend local, khởi động lại `npm.cmd run dev` và dùng `--dart-define=API_BASE_URL=http://10.0.2.2:3000` trên Android emulator.

## 3. Cấp quyền cho quản trị viên

Đăng ký/xác nhận email tài khoản admin như bình thường. Chủ project cấp quyền bằng SQL Editor, thay email bằng tài khoản cần cấp:

```sql
update public.users u
set role = 'ADMIN'
from auth.users a
where u.id = a.id and lower(a.email) = lower('admin@example.com')
returning u.id, u.name, u.role;
```

Kết quả cần trả đúng một tài khoản. Đăng nhập lại hoặc kéo xuống làm mới Tài khoản: xuất hiện **Quản trị phòng tập**. App không cung cấp chức năng tự cấp quyền.

## 4. Luồng sử dụng

1. Hội viên mở Dịch vụ → gói tập → Đăng ký gói tập. Đơn chờ duyệt xuất hiện trong Tài khoản → Hoạt động của tôi.
2. Hội viên thanh toán tại quầy; admin duyệt sau khi nhận thanh toán. Đây là ghi nhận thanh toán thủ công, chưa tích hợp cổng thanh toán. Khi duyệt, gói có hiệu lực; thời hạn còn lại được cộng tiếp và quyền lợi điểm áp dụng theo gói mới.
3. Admin xem QR phòng 1 tự đổi vào đầu mỗi giờ. Mã gồm 10 ký tự chữ in hoa và số, căn giữa dưới QR; nhập mã ngắn không phân biệt hoa/thường. QR được vẽ trong app bằng [qr_flutter](https://pub.dev/documentation/qr_flutter/latest/index.html). Migration 003 lưu mã hiển thị riêng trong bảng chỉ admin RPC đọc được; nghiệp vụ check-in vẫn dùng hash trong qr_tokens.
4. Trang chủ hội viên → Quét QR check-in hoặc nhập mã tại quầy. Cần gói còn hạn. App hiển thị người đang tập, biểu đồ từng giờ Việt Nam, thời gian bắt đầu và nút Check-out. Dữ liệu phòng tập cập nhật mỗi 30 giây khi panel đang mở và có nút cập nhật thủ công.
5. Đổi quà → xác nhận: hệ thống kiểm tra điểm/tồn kho và cập nhật cùng transaction. Trong Hoạt động của tôi có mã nhận quà. Admin kiểm tra mã, giao quà và xác nhận đã giao.
6. Dịch vụ → PT → Chọn lịch tập: giờ tròn 06:00–21:00, 60 phút, trong 30 ngày tới. Lịch trống hiển thị theo giờ Việt Nam. Hủy lịch trước giờ bắt đầu trong Hoạt động của tôi.
7. Admin quản lý quà/gói/PT: thêm, sửa, ẩn và mở lại. Ẩn thay vì xóa vật lý để giữ lịch sử.
8. Đăng ký có nhập lại mật khẩu; không gửi yêu cầu nếu hai mật khẩu khác nhau. Các ô mật khẩu có nút mắt để hiện/ẩn độc lập. Hồ sơ có sửa họ tên, các lối tắt được tách thành thẻ riêng.
9. Chỉnh sửa hồ sơ có chọn ảnh đại diện từ thiết bị; admin chọn ảnh quà/PT khi thêm/sửa. Quên mật khẩu xác nhận bằng mã trong email. Chạy migration 003, cấu hình lịch QR/email và deploy theo [UPDATES_003.md](UPDATES_003.md).

## API mới

Tất cả route dưới đây cần `Authorization: Bearer <access_token>`.

| API | Chức năng |
| --- | --- |
| PATCH `/me` | Sửa họ tên |
| GET `/gym/session` | Buổi tập đang mở của tôi |
| POST `/gym/check-in` | `{token}` QR tại quầy |
| POST `/gym/check-out` | `{session_id}`; gửi lại không đổi giờ checkout |
| GET `/gym/:gym_id/occupancy` | Số người đang tập |
| GET `/gym/:gym_id/hourly?date=YYYY-MM-DD` | Số người có mặt trong từng giờ; mặc định hôm nay |
| GET `/activity?limit=20&offset=0` | Bốn loại lịch sử của tôi |
| GET `/gym/sessions`, `/redemptions`, `/membership-orders`, `/pt-bookings` | Lịch sử riêng từng loại, có limit/offset |
| POST `/redemptions` | `{reward_id,idempotency_key}` |
| POST `/membership-orders` | `{membership_id,idempotency_key}`; tối đa một đơn chờ duyệt |
| GET `/trainers/:id/slots?date=YYYY-MM-DD` | Khung giờ và trạng thái còn trống, không lộ hội viên khác |
| POST `/pt-bookings` | `{trainer_id,slot,idempotency_key}`; slot ISO8601 có timezone |
| POST `/pt-bookings/:id/cancel` | Hủy lịch của mình |
| GET `/admin/dashboard?limit=20&offset=0` | Đơn/quà chờ xử lý và QR còn hạn |
| POST `/admin/qr-tokens` | `{gym_id,minutes}`; trả token thô một lần |
| POST `/admin/qr-tokens/:id/revoke` | Thu hồi QR |
| POST `/admin/membership-orders/:id/review` | `{status:APPROVED hoặc REJECTED}` |
| POST `/admin/redemptions/:id/fulfill` | Xác nhận đã giao quà |
| GET/POST `/admin/rewards`, `/admin/memberships`, `/admin/trainers` | Xem cả mục ẩn/tạo danh mục |
| PATCH `/admin/:catalogue/:id` | Cập nhật những trường được gửi |
| DELETE `/admin/:catalogue/:id` hoặc POST `/admin/:catalogue/:id/archive` | Ẩn danh mục |

Các route `/admin/*` cần `users.role = 'ADMIN'`, được kiểm tra lại bên PostgreSQL. Lỗi nghiệp vụ trả message tiếng Việt và HTTP 400/403/404/409; lỗi cấu hình database trả 503. `/health` kiểm tra kết nối database; không thay thế kiểm tra luồng nghiệp vụ sau khi chạy migration.

## Kiểm thử

Backend: `npm.cmd test` trong `backend`. Có kiểm thử SQL thật bằng PGlite cho schema, RLS, cấp quyền, QR, idempotency, điểm/tồn kho, duyệt đơn, lịch PT và quản lý danh mục; HTTP kiểm tra JWT, dữ liệu đầu vào, hash QR và lỗi nghiệp vụ.

Flutter: `flutter test --dart-define=API_BASE_URL=http://localhost:3000` và `dart analyze lib test`. HTTP trong tests được mock, không tạo tài khoản hoặc ghi lên Supabase thật. Camera và luồng thanh toán/giao quà tại quầy cần kiểm tra trên thiết bị sau khi deploy.
