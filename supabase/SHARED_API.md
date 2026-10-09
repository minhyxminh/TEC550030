# GymFlow — API chung, thành viên chỉ cần Flutter

Mục tiêu: API chạy trên Supabase Edge Functions bằng HTTPS; source Flutter chứa URL chung. Người khác clone repo và chạy app, không chạy Node, không tạo `.env`, không tìm IP LAN. Điện thoại thật dùng Internet, không cần cùng Wi-Fi với máy host backend.

Các thành viên vẫn cần Flutter SDK có Android toolchain và thiết bị/emulator sẵn sàng (`flutter doctor`). Flutter tự cài package khi `flutter pub get`. Server chung cần hoạt động để app tải dữ liệu.

## Nhóm trưởng làm một lần

### 1. Deploy từ Dashboard

1. Mở [project resjlmqdtxubcbdpvtds](https://supabase.com/dashboard/project/resjlmqdtxubcbdpvtds).
2. Vào **Edge Functions → Deploy a new function → Via Editor**.
3. Đặt tên function chính xác **`gymflow-api`**.
4. Mở [`functions/gymflow-api/index.ts`](functions/gymflow-api/index.ts) trong repo. Copy toàn bộ nội dung vào `index.ts` của editor, thay code Hello World.
5. Deploy function.
6. Trong cấu hình của function, **tắt Verify JWT / Enforce JWT Verification** (tên menu có thể thay đổi). Đây là kiểm tra JWT ở gateway trước khi code chạy; login/register cần chạy khi chưa có JWT. Bản deploy vẫn tự xác minh JWT cho `/me` và `/points/*`, và truy vấn dữ liệu riêng tư bằng JWT + RLS. Không tắt RLS trong database.

Function dùng environment Supabase tự cấp: URL và publishable/anon key; không dùng secret/service_role và không copy `.env` của máy vào source. Không chạy lại migration `001` hoặc seed nếu database đã được tạo.

URL sau khi deploy:

```text
https://resjlmqdtxubcbdpvtds.supabase.co/functions/v1/gymflow-api
```

Nguồn hướng dẫn chính thức: [Deploy qua Dashboard](https://supabase.com/docs/guides/functions/quickstart-dashboard), [Express/routing có prefix function](https://supabase.com/docs/guides/functions/routing), [Auth và verify_jwt](https://supabase.com/docs/guides/functions/auth), [Environment được cấp sẵn](https://supabase.com/docs/guides/functions/secrets).

### 2. Kiểm tra API online và bật mặc định cho Flutter

Trong PowerShell ở thư mục gốc repo:

```powershell
cd D:\TEC550030
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\enable_shared_api.ps1
```

Script kiểm tra `/health`, `/rewards`, `/memberships`, `/trainers` qua HTTPS. Chỉ khi tất cả thành công mới ghi URL chung vào [`../tec550030/lib/core/api/shared_api_config.dart`](../tec550030/lib/core/api/shared_api_config.dart). Cấu hình hiện tại đã có URL API chung; dùng script khi cần xác minh hoặc đổi URL.

Nếu báo 404/FUNCTION_NOT_FOUND: chưa deploy đúng tên function. Nếu 401/Missing authorization header ở `/health`: platform JWT verification còn bật. Nếu 503: xem Logs của function, kiểm tra project/database hoạt động và schema/RLS đã được áp dụng.

Có thể kiểm tra riêng trong trình duyệt:

```text
https://resjlmqdtxubcbdpvtds.supabase.co/functions/v1/gymflow-api/health
```

Mong đợi: `{"status":"ok","database":"connected"}`.

### 3. Commit/push code sau khi bật URL chung

Commit các file mới của bản deploy, script, `.vscode/launch.json` và `shared_api_config.dart` đã được script cập nhật. Không commit `.env` hoặc `node_modules`. URL HTTPS là địa chỉ công khai, không phải mật khẩu/API secret.

Sau đó kiểm tra trên app: đăng ký (xác nhận email nếu yêu cầu), login, profile, ví điểm, rewards và các trang gói/PT. Kiểm thử local không thay thế kiểm tra function đã deploy trên Supabase.

## Mọi thành viên làm khi tải code

Ví dụ clone repo vào thư mục bất kỳ, mở terminal trong thư mục Flutter `tec550030`:

```powershell
flutter pub get
flutter run
```

Không truyền `API_BASE_URL`; app dùng URL chung đã commit. Có thể chọn cấu hình **GymFlow** trong Run and Debug của VS Code nếu mở thư mục gốc repo.

Điện thoại Android thật: bật Developer options/USB debugging, nối USB, chấp nhận Allow USB debugging, kiểm tra `flutter devices`, rồi `flutter run -d DEVICE_ID`. Máy tính và điện thoại có thể dùng mạng khác nhau; điện thoại cần truy cập Internet.

Nếu muốn người nhận chỉ cài và mở app, nhóm build APK sau khi đã bật URL chung:

```powershell
flutter build apk --release
```

File ở `tec550030/build/app/outputs/flutter-apk/app-release.apk`. Người cài APK không cần Flutter hoặc máy tính. Để bật QR/đổi quà/đặt gói/PT và quản trị, chạy migration và deploy phiên bản mới theo [WORKFLOWS.md](WORKFLOWS.md).

## Backend developer tiếp tục làm việc

Express local vẫn dùng được khi truyền override:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

API cloud dùng đúng route handlers từ `backend/src/app.js`, không duy trì bản logic riêng. Khi sửa API hoặc dependency:

```powershell
cd backend
npm.cmd run build:edge
npm.cmd test
```

Copy lại file `index.ts` đã sinh vào Dashboard và deploy bản mới. `npm` chỉ cần trên máy người phát triển backend. Rate limit trong Express dùng memory từng instance; với Edge Functions đây là giới hạn best effort, không phải bộ đếm chung giữa tất cả worker.

Nếu dùng Supabase CLI đã đăng nhập, có thể deploy từ gốc repo bằng `supabase functions deploy gymflow-api --project-ref resjlmqdtxubcbdpvtds --no-verify-jwt`; Dashboard là cách không cần cài CLI.
