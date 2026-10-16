# GymFlow Phase 2

Cập nhật mới ngày 16/10/2026: xem [Sức khỏe và cơ sở](HEALTH_BRANCH_UPDATE.md), gồm lịch sử cân nặng, thước kéo, gợi ý BMI theo nhóm và migration 010 khi hủy membership.

## DONE

- QR chung: dùng QR hợp lệ của cơ sở `1` để check-in tại `users.home_gym_id`, gồm `q6`, `q7`. Vẫn kiểm tra membership, thời hạn/thu hồi QR, session mở và +5 GP tối đa một lần/ngày.
- Biểu đồ occupancy hiển thị từng giờ backend trả về, kể cả count=0; cuộn ngang với 48 px/giờ, giữ highlight giờ hiện tại.
- Thanh điều hướng: Trang chủ | Sức khỏe | Đổi thưởng | Dịch vụ | Tài khoản. Các liên kết số dư trên Home/Tài khoản đi đến Đổi thưởng.
- Sức khỏe: BMI, kiểm tra dữ liệu, phân loại, thang màu, 5 gợi ý và kết quả gần nhất lưu riêng theo tài khoản trên thiết bị.
- Đổi thưởng: số dư GP từ API, lịch sử có phân trang qua màn ví hiện có, danh mục và redeem hiện có. Revision của workflow làm mới số dư/stock sau đổi quà.
- Chat text Member–Admin: nút nổi, hộp thư Admin với số tin chưa đọc, trả lời, tải tin cũ, polling 4–5 giây khi màn hình ở foreground; retry cùng nội dung dùng lại client_id để tránh gửi trùng. Không gửi thông báo ngoài ứng dụng.
- Ghi nhớ đăng nhập: checkbox, nhớ email, dùng access/refresh token hiện có. Bỏ chọn thì token chỉ tồn tại trong bộ nhớ tiến trình; đóng hẳn ứng dụng rồi mở lại phải đăng nhập. Không lưu mật khẩu.
- Sinh trắc học: bật tại Tài khoản sau khi ghi nhớ phiên; xác thực khi SessionGate khôi phục phiên lúc khởi động. Hủy, thất bại hoặc không hỗ trợ quay về mật khẩu và xóa phiên cục bộ. Logout/đăng nhập tài khoản khác xóa lựa chọn sinh trắc học.
- Card giữ màu GymFlow, bo góc 18 px, viền mảnh; thẻ điểm thích ứng với màn hình hẹp và chữ lớn.

## CHANGED

- `supabase/migrations/008_global_qr_checkin.sql`: thay FK `(qr_token_id,gym_id)` bằng FK `qr_token_id`, cập nhật check_in; giữ trigger session phải thuộc home gym và trigger giới hạn điểm. Không sửa migrations 001–007.
- `supabase/migrations/009_chat.sql`: conversations/messages, RLS, RPC `gymflow_chat`; ghi dữ liệu qua RPC kiểm tra danh tính từ JWT. Member chỉ đọc hội thoại của mình; Admin được đọc và trả lời. `client_id` chống gửi trùng; sequence làm cursor tải tin cũ.
- `backend/src/app.js` và bản sinh `supabase/functions/gymflow-api/index.ts`: API `/chat/open`, `/chat/inbox`, `/chat/:id/messages`, `/chat/:id/read`.
- Flutter: `screens/health`, `screens/chat`, service BMI/chat/biometric, session/login, tab điều hướng, rewards, profile, chart và test.
- Android: `FlutterFragmentActivity`, USE_BIOMETRIC, AppCompat LaunchTheme. iOS: Face ID usage description. Dependency `local_auth` đã được khóa trong pubspec.lock.

## PENDING

Chưa áp dụng migration hoặc deploy API lên Supabase đang dùng. Trình tự triển khai:

1. Trên database đã có 001–007, chạy **008 rồi 009**, mỗi file có transaction riêng. Không chạy lại migrations cũ.
2. Deploy lại Edge Function `gymflow-api` từ source đã sinh trong repo. Nếu dùng Express riêng, khởi động lại backend với mã mới.
3. Cài bản Flutter mới. Backend và DB cần nâng cấp trước để tính năng chat có endpoint/RPC tương ứng.
4. Kiểm tra Samsung thực tế; phiên làm việc này không phát hiện thiết bị Android kết nối.

Chưa xác nhận build APK mới. Lượt build debug đã được dừng khi ổ C gần đầy và Gradle dùng cấu hình heap 8 GiB có sẵn của dự án. Cần đủ dung lượng trống trước khi build lại; không thay đổi cấu hình Gradle toàn máy hoặc xóa cache/dữ liệu cá nhân để giải phóng ổ đĩa.

Kiểm tra thiết bị thật: GPS allow/deny → chọn q6 → kích hoạt gói → dùng QR chung cơ sở 1 → occupancy q6 tăng → checkout → check-in lại không thêm GP → đổi thưởng và số dư/stock → BMI và mở lại kết quả → Member gửi/Admin trả lời → logout/đổi tài khoản không lộ chat → ghi nhớ bật/tắt qua force-stop → sinh trắc học thành công/hủy/khóa/tắt hỗ trợ → dịch vụ/tài khoản.

Sinh trắc học hiện bảo vệ khôi phục phiên lúc khởi động, không phải khóa sau mỗi lần chuyển ứng dụng sang nền. Token tiếp tục dùng cơ chế persistence hiện có; không thêm kho mật khẩu hoặc thay đổi auth server.

## TESTED

Kết quả ngày 16/10/2026: **35/35 kiểm thử backend** và **48/48 kiểm thử Flutter** đạt; `flutter analyze` không có lỗi/cảnh báo và `git diff --check` đạt. Flutter test chạy tuần tự, file tạm chuyển sang `D:\GymFlowPhase2Temp-20261016` vì lần chạy trên ổ C gặp lỗi hết dung lượng. Không có kiểm thử trên Supabase thật hoặc cảm biến sinh trắc học thật.

Các lệnh xác minh:

```powershell
cd backend
node --test
node scripts/build-edge.mjs
cd ../tec550030
flutter analyze
flutter test
flutter build apk --debug --no-pub
cd ..
git diff --check
```

Để tái lập lượt Flutter test đã đạt trên máy này (chỉ đổi biến môi trường của cửa sổ PowerShell hiện tại):

```powershell
New-Item -ItemType Directory -Path D:\GymFlowPhase2Temp-20261016 -Force
$env:TEMP = 'D:\GymFlowPhase2Temp-20261016'
$env:TMP = $env:TEMP
flutter test --concurrency=1
```

Test database chạy trên PostgreSQL WASM (PGlite) với auth/storage giả lập; không thay đổi dữ liệu Supabase thật. Bao gồm toàn bộ migration 001–009, QR chung q6/1/q7, membership/home gym bắt buộc, QR invalid/expired/revoked, không nhân đôi session/GP, checkout, RLS chat, chống giả sender và chống retry trùng. Test Flutter dùng API và biometric giả lập; không thay thế kiểm thử cảm biến trên Samsung.

Một số kiểm thử cũ được cập nhật theo hành vi đã có ở Phase 2A: cơ sở người dùng chọn được giữ sau duyệt gói; đọc hồ sơ dưới danh tính đúng theo RLS; điểm check-in là 5; mock Edge dùng RPC hồ sơ. Kiểm thử giao diện cuộn nút vào vùng nhìn thấy trước khi bấm.

BMI dùng ngưỡng người lớn từ 20 tuổi theo [CDC](https://www.cdc.gov/bmi/adult-calculator/bmi-categories.html): <18,5 / 18,5–<25 / 25–<30 / ≥30. Giới hạn nhập 20–350 kg, 100–250 cm, 20–120 tuổi là giới hạn của tính năng demo. Hướng dẫn sinh trắc học: [local_auth](https://pub.dev/packages/local_auth) và [cấu hình Android](https://pub.dev/packages/local_auth_android).
