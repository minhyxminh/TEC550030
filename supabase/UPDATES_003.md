# Kích hoạt QR theo giờ, upload ảnh và quên mật khẩu

Thay đổi đã có trong code: hướng dẫn camera nằm sát dưới khung quét, admin xem lại QR đã lưu sau khi đóng/mở màn hình, QR tự đổi vào đầu mỗi giờ, upload ảnh hồ sơ/quà/PT, quên mật khẩu qua mã xác nhận email. Các nút phân trang admin được thay bằng **Xem thêm** khi còn dữ liệu.

Chủ project cập nhật Supabase một lần theo các bước dưới đây. Thành viên sau đó chạy `flutter pub get` và `flutter run`.

## 1. Chạy migration mới

Mở [project Supabase](https://supabase.com/dashboard/project/resjlmqdtxubcbdpvtds), **SQL Editor → New query**, dán toàn bộ `supabase/migrations/003_media_hourly_qr.sql`, chọn **Run**.

File chạy sau migration 001/002. Có thể chạy lại 003; giữ hồ sơ, buổi tập, điểm và danh mục hiện có. Không chạy lại 001.

Migration tạo bucket public **gymflow-images** cho ảnh JPG/PNG/WebP tối đa 3 MB, thêm `users.avatar_path`, RPC cập nhật hồ sơ và bảng **gym_qr_displays** lưu mã cho màn hình admin. Hội viên chỉ được tải ảnh vào thư mục avatar của chính mình; tải ảnh quà/PT cần ADMIN. Bảng mã QR không có quyền đọc trực tiếp cho client; RPC kiểm tra ADMIN trước khi trả mã. Cơ chế Storage RLS theo [tài liệu Supabase](https://supabase.com/docs/guides/storage/security/access-control).

Ảnh đã lưu có URL public để app hiển thị. Tài khoản không có ảnh dùng biểu tượng người dùng. API không lấy ảnh từ metadata mạng xã hội nữa.

## 2. Bật lịch đổi QR mỗi giờ

1. Trong Dashboard, mở **Integrations → Cron**, bật extension **pg_cron** nếu chưa bật. Một số giao diện có **Database → Extensions → pg_cron**.
2. Mở SQL Editor, dán file `supabase/schedule_hourly_qr.sql`, chọn **Run**.
3. Kiểm tra lịch:

   ```sql
   select jobid, jobname, schedule, command, active
   from cron.job
   where jobname = 'gymflow-hourly-qr';
   ```

   Cần một job `active = true`, lịch `0 * * * *`, command `select public.gymflow_rotate_all_qr();`.

Lịch chạy trong database nên admin không cần giữ app hoặc Node mở. Nếu bật lúc 15:20, mã đầu tiên dùng đến 16:00; các mã sau dùng trong từng giờ 16:00–17:00, 17:00–18:00… Múi giờ Việt Nam lệch UTC đúng 7 giờ nên đầu giờ UTC cũng là đầu giờ Việt Nam. Nếu mã bị thu hồi, QR ngừng hiện và mã tiếp theo được tạo vào đầu giờ kế tiếp. Lịch/running jobs xem theo [Supabase Cron](https://supabase.com/docs/guides/cron/quickstart).

Khi mở admin, API cũng kiểm tra và tạo mã cho giờ hiện tại nếu lịch bị chậm. Hai admin mở đồng thời nhận cùng một mã nhờ transaction lock. Màn hình cập nhật ở thời điểm hết hạn, kiểm tra thu hồi mỗi 30 giây và tải lại khi app trở về foreground.

## 3. Đổi template email Reset Password thành mã xác nhận

App dùng **mã trong email**, sau đó nhập mã, mật khẩu mới và nhập lại ngay trong app. Mã được xác minh với Supabase dưới loại `recovery`; API chỉ đổi mật khẩu sau khi xác minh thành công.

1. Mở **Authentication → Emails → Templates → Reset Password**. Một số giao diện ghi **Email Templates → Reset Password**.
2. Subject: `Mã xác nhận đặt lại mật khẩu GymFlow`.
3. Thay Body bằng nội dung file `supabase/templates/reset_password.html`, chọn **Save**. Không thay template Confirm signup đang dùng cho đăng ký.

Biến `{{ .Token }}` chứa mã xác nhận của Supabase. Template này không cần link mở app hoặc cấu hình deep link. Tham khảo [Email Templates](https://supabase.com/docs/guides/auth/auth-email-templates).

Nếu email chưa đến, kiểm tra Spam và mục **Authentication → Logs**. Khi báo địa chỉ nhận chưa được cho phép hoặc giới hạn gửi email, cấu hình **Custom SMTP** để gửi tới email của các thành viên; xem [hướng dẫn SMTP](https://supabase.com/docs/guides/auth/auth-smtp). App cho gửi lại sau 60 giây; mã chỉ dùng một lần. Nếu mã hết hạn hoặc đã được sử dụng, yêu cầu mã mới.

## 4. Deploy API và chạy lại Flutter

1. VS Code: mở `supabase/functions/gymflow-api/index.ts`, **Ctrl+A → Ctrl+C**.
2. Dashboard: **Edge Functions → gymflow-api → Code → index.ts**, thay toàn bộ nội dung, **Deploy updates**. Giữ Verify JWT ở gateway tắt như cấu hình hiện tại; các route riêng tự kiểm tra JWT.
3. Dừng Flutter và chạy:

   ```powershell
   cd D:\TEC550030\tec550030
   flutter pub get
   flutter run
   ```

Plugin, UI, API và callback đăng nhập Google đã được gỡ. Nếu trước đó đã bật provider Google trong Dashboard, vào Authentication → Providers để tắt provider đó; URL callback cũ có thể xóa trong URL Configuration. Thao tác này không xóa tài khoản hoặc dữ liệu đang có.

## 5. Thử các luồng

- **Camera:** hướng dẫn có nền tối ngay dưới khung vuông, nằm trong vùng an toàn của màn hình.
- **Admin QR:** mở admin thấy QR ngay, vào quản lý danh mục rồi quay lại vẫn cùng mã. Qua đầu giờ mã đổi tự động. Thu hồi mã sẽ ngừng cho check-in đến giờ tiếp theo.
- **Avatar:** Tài khoản → Chỉnh sửa hồ sơ → Chọn ảnh từ thiết bị → Lưu hồ sơ. Quay lại kiểm tra ảnh, đóng/mở app kiểm tra lại.
- **Quà/PT:** Quản trị → Quản lý danh mục → Thêm/Chỉnh sửa → Chọn ảnh từ thiết bị → Lưu. Form có preview ảnh; URL được lưu tự động sau upload.
- **Quên mật khẩu:** Đăng nhập → Quên mật khẩu? → nhập email → Gửi mã → nhận email → nhập mã, mật khẩu mới và nhập lại → Đặt lại mật khẩu → đăng nhập bằng mật khẩu mới. Các ô mật khẩu có nút mắt độc lập. API trả thông báo gửi email chung để không tiết lộ email nào đã đăng ký.
- **Nhiều dữ liệu admin:** dùng Xem thêm khi vượt một nhóm 20 bản ghi; khi ít dữ liệu không có nút thừa. Cơ chế phân trang ở API vẫn giữ để không bỏ sót dữ liệu.

## API bổ sung

| Route | Dữ liệu / quyền |
| --- | --- |
| POST `/auth/forgot-password` | `{email}`, không cần JWT |
| POST `/auth/reset-password` | `{email,token,password}`, xác minh recovery OTP, không trả session |
| POST `/media/avatars` | Binary image, Content-Type image/jpeg/png/webp, JWT hội viên |
| POST `/media/rewards`, `/media/trainers` | Binary image, JWT ADMIN |
| PATCH `/me` | `{name,avatar_path?}`, chỉ chấp nhận ảnh đã upload trong thư mục của người dùng |
| GET `/me` | Thêm avatar_path và avatar_url từ Storage |
| GET `/admin/qr-current` | ADMIN, mã 10 ký tự hiện tại cùng ngày hết hạn/trạng thái thu hồi |

Source backend vẫn ở `backend/src/`. Khi sửa source, chạy `npm.cmd run build:edge` trong backend để sinh lại index.ts rồi deploy. Tests dùng database PostgreSQL giả lập và HTTP fixtures; không gửi email hoặc ghi dữ liệu lên project thật. Kiểm tra email thật, thư viện ảnh và Cron sau khi cấu hình/deploy các bước trên.
