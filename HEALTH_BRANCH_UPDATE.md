# Cập nhật Sức khỏe và cơ sở – 16/10/2026

## Thay đổi

- Dashboard điểm danh lấy tên cơ sở từ catalogue /gyms theo home_gym_id; khi đang có session thì dùng cơ sở của session. Home truyền BranchService hiện có để các luồng chọn cơ sở và hiển thị dùng cùng nguồn dữ liệu.
- Migration mới: supabase/migrations/010_cancel_membership_clear_home_gym.sql. Hủy gói sẽ đặt users.home_gym_id = null, hết hạn membership và đóng session đang mở trong cùng transaction. Không xóa gyms, session, đơn gói tập hoặc ledger điểm. Có thể chọn lại cơ sở ngay và đăng ký gói mới.
- Màn Sức khỏe có dashboard cân nặng hiện tại, cao nhất, thấp nhất, thay đổi so với lần đầu và biểu đồ tối đa 30 lần đo gần nhất. Chỉ vẽ những lần đo đã lưu; không tạo dữ liệu mẫu.
- Dashboard cân nặng mở bảng chỉ có thước kg. Phần chỉnh sửa BMI vẫn có cân nặng, chiều cao và tuổi. Bảng nhập đã thu gọn; nút Lưu/Hủy cố định ngoài vùng cuộn và nằm trên bàn phím/vùng điều hướng hệ thống. Khoảng cách vạch thước giảm từ 12 xuống 6 px để kéo nhanh hơn; vẫn giữ độ chính xác 0,1 kg và 1 cm. Hủy không ghi dữ liệu.
- Ghi riêng cân nặng giữ chiều cao/tuổi đã có để tính lại BMI; tài khoản chưa có chiều cao/tuổi chỉ lưu lịch sử cân nặng, không tạo BMI từ số mặc định.
- Lịch sử lưu cục bộ theo tài khoản ở health_<userId>; mỗi ngày Việt Nam giữ lần cập nhật mới nhất. Đọc được kết quả cũ ở bmi_<userId> và chuyển sang định dạng mới khi lưu lần tiếp theo.
- Thang BMI có mốc 15 / 16 / 18,5 / 25 / 30 / 35 / 40 và chỉ báo vị trí. Phân loại vẫn dựa trên giá trị tính chưa làm tròn, dùng cho người từ 20 tuổi.
- Gợi ý riêng cho BMI <18,5; 18,5–<25; 25–<30; 30–<35 và ≥35, có lưu ý thêm cho ≥40. Mỗi nhóm có năm mục cụ thể về vận động, dinh dưỡng, nước, ngủ/phục hồi và theo dõi/hỗ trợ. Đây là gợi ý tham khảo, không phải chẩn đoán.

## Triển khai

1. Trên Supabase đã có migrations 001–009, chạy file 010 mới trong SQL Editor.
2. Cài/chạy bản Flutter mới.
3. API hủy membership vẫn dùng endpoint hiện có và tên RPC cũ, không cần endpoint mới. Chưa tự chạy migration trên Supabase thật trong phiên chỉnh sửa này.
4. Sau khi Admin hủy gói, hội viên làm mới Trang chủ để tải trạng thái và chọn lại cơ sở. Không thêm thông báo realtime cho thay đổi membership.

## Xác minh

Kết quả: 54/54 kiểm thử Flutter và 35/35 kiểm thử backend đạt. Ảnh dashboard, BMI, thước kéo đã được xuất và kiểm tra trực quan.

Test database kiểm tra: quyền Admin, home_gym_id bị xóa, session mở được đóng, số session/điểm được giữ nguyên, đơn hiện tại CANCELLED, chọn cơ sở mới và mua/kích hoạt/check-in gói mới.

Test Flutter kiểm tra: thước kéo kg/cm, Hủy không lưu, tuổi ngoài giới hạn, công thức BMI, nội dung gợi ý theo nhóm, lịch sử riêng tài khoản, giữ lần đo mới nhất theo ngày Việt Nam, chuyển dữ liệu cũ, tên cơ sở q6, giao diện 320 px/chữ lớn và thông báo hủy gói mới. Ảnh xem trước nằm trong tec550030/.dart_tool/ui_previews/health-dashboard.png, health-bmi.png, health-rulers.png.

## Nguồn nội dung gợi ý

- [CDC – Phân loại BMI người lớn](https://www.cdc.gov/bmi/adult-calculator/bmi-categories.html)
- [CDC – Vận động cho người lớn](https://www.cdc.gov/physical-activity-basics/guidelines/adults.html)
- [NHS – Tăng cân lành mạnh](https://www.nhs.uk/live-well/healthy-weight/managing-your-weight/healthy-ways-to-gain-weight/)
- [NHS – Ăn uống cân bằng](https://www.nhs.uk/live-well/eat-well/how-to-eat-a-balanced-diet/eight-tips-for-healthy-eating/)
- [NHS – Thừa cân và béo phì](https://www.nhs.uk/conditions/overweight-and-obesity/)

Bản thu gọn bảng nhập: 20 kiểm thử Flutter liên quan đã đạt, bao gồm popup chỉ cân nặng, không tạo BMI giả, giữ chiều cao/tuổi, nút Lưu ở màn hình 360×640 với chữ lớn và bàn phím mở.
