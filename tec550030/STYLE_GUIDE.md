# GymFlow style guide (mini)

Mood: "Hổ Flow" — hình khối tròn, màu phẳng, nét tối giản, vui nhưng gọn.
Mọi giá trị dưới đây có token trong `lib/core/theme/`, nên dùng token, không viết mã màu trực tiếp.

## Màu (`AppColors`)

| Token | Hex | Dùng cho |
|---|---|---|
| `primaryOrange` (Cam hổ) | `#FF7A3D` | Màu nhấn, card nổi bật, tab đang chọn, nút chính |
| `ink` (Mực) | `#1E1B2E` | Chữ, nút màu mực, thanh điều hướng, thẻ GymPoint |
| `purple` (Tím) | `#8B6CFF` | Nút chat, icon phụ, chấm trang trí |
| `mint` (Bạc hà) | `#DDF5E6` | Nền trạng thái tốt |
| `warmBackground` (Nền) | `#F7F5FB` | Nền màn hình |
| `lavender` / `field` | `#EEEAFB` / `#F3F1F9` | Ô icon, ô nhập, ô chỉ số |
| `peach` / `butter` | `#FFE6D9` / `#FFF1D1` | Ô icon cam / vàng |
| `deepOrange` | `#C94A14` | Chữ cam trên nền sáng (điểm GP, link) |
| `gymPointYellow` | `#FFB547` | Huy hiệu GP, nút "Xem ví điểm" |
| `success` / `info` / `warning` / `error` | `#1E9E5E` / `#3B7BF0` / `#F08A24` / `#D9363E` | Trạng thái |

Màu BMI: thiếu cân dùng `info`, khỏe mạnh dùng `success` (nền `mint`), thừa cân dùng `warning`, béo phì dùng `error`.

## Card, nút, khoảng cách (`AppRadius`, `AppSpacing`, `AppShadows`)

- Card thường (`AppCard`): nền trắng, bo 24, không viền, bóng rất nhẹ.
- Card nổi bật (`HighlightCard` trong `lib/widgets/ambient.dart`): nền cam hoặc mực, bo 28. Có **bong bóng trắng mờ trôi và lúc rõ lúc mờ**, kèm **viền sáng "thở"** quanh card. Dùng cho: card chào ở Trang chủ, thẻ GymPoint, gói tập nổi bật, card linh vật và card gợi ý ở Sức khỏe. Phần đầu màn đăng nhập dùng `AmbientBubbles`.
- Icon luôn đặt trong ô màu nhạt bo góc (`IconTile`).
- Nút chính (`AppButton`): cam, chữ mực, có bóng khối màu mực bên dưới. Nút màu mực dùng `dark: true`; nút phụ dùng viền.
- Thanh điều hướng (`GymFlowNavBar`): thanh màu mực nổi, tab đang chọn nằm trên ô cam. Nút chat là ô vuông bo màu tím.
- Khoảng cách: 4 / 8 / 12 / 16 / 20, lề trang 20, giữa các section 28. Danh sách chừa `navClearance` (120) ở đáy cho thanh điều hướng.
- Ảnh trong test không vẽ được bóng mờ, nên bóng hiện thành vệt xám đặc. Trên máy thật bóng mềm bình thường.

## Chữ (`AppTextStyles`)

Font nằm trong `assets/fonts` (kèm giấy phép OFL). Baloo 2 đã được cắt chỉ giữ chữ Latin và tiếng Việt.

| Style | Font | Size / weight | Dùng cho |
|---|---|---|---|
| `display` | Baloo 2 | 34 / 800 | Số lớn (giá, điểm, BMI) |
| `heading1` | Baloo 2 | 26 / 800 | Tiêu đề màn hình, tên |
| `heading2` | Baloo 2 | 19 / 700 | Tiêu đề section, card |
| `title` | Be Vietnam Pro | 15 / 700 | Tên item, nhãn nút |
| `body` | Be Vietnam Pro | 14 / 400 | Nội dung |
| `caption` | Be Vietnam Pro | 12.5 / 500 | Mô tả phụ |

Tên app luôn dùng `GymFlowWordmark` (cắt trực tiếp từ logo). Trên nền cam, đặt wordmark trong một pill trắng để giữ đúng màu logo.

## Chuyển động

- Bong bóng và viền sáng lặp liên tục. Linh vật có vòng idle riêng (xem bên dưới).
- Tất cả tự dừng khi máy bật "giảm chuyển động". Trong test, `test/flutter_test_config.dart` tắt `AppMotion.ambient` và `Mascot.idleMotion`.

## Linh vật (Hổ Flow)

Chuyển động dựng từ chính các khung hình hoạt ảnh gốc (`assets/mascot/*.webp`, cắt từ video của bạn), không vẽ lại nhân vật. Code chọn khung theo thời gian và thêm chuyển động thân, aura, hiệu ứng phụ (`lib/widgets/mascot.dart`).

| Trạng thái | Khung hình | Chuyển động | Dùng ở |
|---|---|---|---|
| `neutral` (Sẵn sàng) | idle 00–24: đứng, vẫy đuôi, chớp mắt | thở 2,6 s, nhích lên, nghiêng nhẹ, aura sáng | Đăng nhập, thẻ chào Trang chủ |
| `happy` | happy 00–01: nắm tay → giơ tay | nhảy 1 s (nén, duỗi, lên 8%), 3 ngôi sao | Đổi quà thành công, BMI tốt |
| `celebrate` | celebrate 00–09: hai tay chữ V | nhảy 10,5% mỗi 0,8 s, lắc ±3°, confetti 26 mảnh | Check-in thành công, đạt mục tiêu tuần |
| `strong` | strong 00–04: thế đấm bốc | gồng nhịp, tia sét | BMI tốt + tập đều |
| `tired` | tired 00–18: mồ hôi, thở dốc, mắt lờ đờ | thở gấp 0,7 s | Sau check-out, BMI cần cải thiện |
| `thinking` | idle 14–24 | nghiêng −5° ↔ +4°, bong bóng "?" | Chưa có dữ liệu, trạng thái trống |
| `sleeping` | idle 10–12 (mắt nhắm) | gục đầu, thở sâu 3,4 s, 3 chữ Z | Đang tải, sau 22h trên Trang chủ |
| `underweight` | idle 14–24, nhỏ hơn 14% | thở nhẹ, huy hiệu pin + bát cơm | BMI thiếu cân |

- Chạm vào linh vật: nhảy lên. Đổi trạng thái: cross-fade 250 ms.
- Chỉ giải mã khung của trạng thái đang dùng, đúng kích thước hiển thị.
- Tự đứng yên khi máy bật "giảm chuyển động". Test tắt chuyển động qua `test/flutter_test_config.dart`.
- `showMascotToast` hiện thẻ linh vật 3 giây cho các cột mốc.
- Lời thoại luôn tích cực, không nhận xét về cơ thể (`lib/models/mascot_mood.dart`).
- Logo, icon app dùng `images/đầu hổ trong suốt.png`.

## Bài tập nổi bật (video)

Dữ liệu nằm trong `lib/models/machine_guide.dart`. Mỗi bài có `videoUrl` và `youtubeId`; ảnh bìa lấy tự động từ YouTube, khi offline thì hiện hình gradient của app. Nút "Xem ngay" phát video ngay trong app (`GuideVideoScreen`, dùng `youtube_player_iframe`); nút ↗ trên màn video mở bằng app YouTube. Chạm vào card thì mở trang hướng dẫn chi tiết.
