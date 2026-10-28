# Đại chiến Boss và trung tâm thông báo

Thay đổi đã có trong code:

- **Trung tâm thông báo**: chuông ở trang chủ có số chưa đọc; banner trượt xuống khi có tin mới. Hội viên được báo tin nhắn (GymFlow, Gym Buddy), Gym Match, gói tập được duyệt, quà đã giao, lịch PT. Admin được báo tin nhắn hỗ trợ, đơn gói tập mới, quà chờ giao. Cả hai đều nhận tin nhắn Gym Buddy và thông báo Đại chiến Boss.
- **Đại chiến Boss**: mỗi tháng có một boss chung. Lượt check-in **đầu tiên trong ngày** của mỗi hội viên, ở bất kỳ chi nhánh nào, cộng 1 HP cho Hổ Flow (cùng luật một lần mỗi ngày như GymPoint). Trận chiến mở khi Hổ Flow đủ máu hoặc vào tuần cuối tháng. Thắng thì **mọi hội viên được cộng 20 GP vào ví ngay**, mỗi người một lần. Ba chi nhánh góp sức nhiều nhất được vinh danh.

Thông báo chạy trong app (kiểm tra mỗi 15 giây khi app đang mở), không cần thêm bảng nào trên Supabase.

Chủ project cập nhật Supabase một lần theo các bước dưới đây. Thành viên sau đó chạy `flutter pub get` và `flutter run`.

## 1. Chạy migration mới

Mở [project Supabase](https://supabase.com/dashboard/project/resjlmqdtxubcbdpvtds), **SQL Editor → New query**, dán toàn bộ `supabase/migrations/015_boss_battle.sql`, chọn **Run**. Nếu Supabase cảnh báo thao tác nguy hiểm, chọn **Run this query**: file chỉ gỡ rồi tạo lại ràng buộc điểm để thêm loại thưởng Boss, không xóa dữ liệu.

Có thể chạy lại 015 bất cứ lúc nào; giữ nguyên hội viên, check-in và điểm.

Migration tạo bảng `boss_battles` (một dòng mỗi tháng), cột `point_transactions.boss_month` cho thưởng Boss và hàm `gymflow_boss`. Hàm đếm check-in của mọi hội viên nhưng chỉ trả về tổng số, không lộ ai check-in.

## 2. Deploy lại Edge Function

**Edge Functions → gymflow-api → Code**, mở `index.ts`, thay toàn bộ nội dung bằng file `supabase/functions/gymflow-api/index.ts` trong repo, chọn **Deploy**. File này được sinh từ `backend/src/app.js` bằng `cd backend && npm run build:edge`.

API thêm `GET /boss` (máu Hổ Flow, máu boss, chi nhánh dẫn đầu) và `POST /boss/fight` (giao chiến).

## 3. Chỉnh máu boss hoặc phần thưởng (tuỳ chọn)

Máu boss mặc định 30 HP, thưởng 20 GP. Đổi cho tháng hiện tại:

```sql
update public.boss_battles
set boss_hp = 30, reward_points = 20
where month = date_trunc('month', now() at time zone 'Asia/Ho_Chi_Minh')::date
  and defeated_at is null;
```

## 4. Kiểm tra

Đăng nhập app, kéo trang chủ để tải lại. Thẻ **Đại chiến Boss** hiện `Hổ Flow x / y HP` là đã xong. Nếu thẻ báo "đang được cập nhật trên máy chủ" thì bước 1 hoặc 2 chưa chạy.
