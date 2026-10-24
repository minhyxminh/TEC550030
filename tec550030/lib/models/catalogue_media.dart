/// Photos bundled with the app for catalogue items, keyed by server id.
/// They take precedence over `image_url` so the catalogue always shows
/// the curated GymFlow photos.
const _rewardImages = {
  '20000000-0000-4000-8000-000000000001': 'assets/catalogue/reward_water.jpg',
  '20000000-0000-4000-8000-000000000002': 'assets/catalogue/reward_protein.jpg',
  '20000000-0000-4000-8000-000000000003': 'assets/catalogue/reward_towel.jpg',
  '20000000-0000-4000-8000-000000000004':
      'assets/catalogue/reward_drink_voucher.jpg',
  '7f5afadc-81ab-45ba-89b2-ab22c8944ce0':
      'assets/catalogue/reward_food_voucher.jpg',
};

/// Proper copy for records that still hold placeholder text on the server
/// (fixed for good by supabase/migrations/014_catalogue_copy.sql).
const _rewardCopy = {
  '7f5afadc-81ab-45ba-89b2-ab22c8944ce0': (
    'Voucher thức ăn',
    'Voucher một phần đồ ăn nhẹ tại quầy GymFlow sau buổi tập.',
  ),
  '817a5512-f3d6-464b-b561-2d446dcc5dd6': (
    'Bình nước Gymflow',
    'Bình nước thể thao GymFlow, tiện mang theo mỗi buổi tập.',
  ),
};

/// Introductions used while a trainer's own description is missing.
const _trainerIntros = {
  '30000000-0000-4000-8000-000000000001': 'Chuyên huấn luyện sức mạnh với các bài compound như squat, deadlift và bench press. Minh giúp bạn tập đúng kỹ thuật và tăng tạ an toàn theo giáo án từng tuần.',
  '30000000-0000-4000-8000-000000000002': 'Tập trung vào thể lực tổng quát và độ linh hoạt của khớp. Lan kết hợp mobility, core và cardio nhẹ, phù hợp người mới bắt đầu hoặc cần cải thiện tư thế.',
  '031109d5-a072-4bf6-9916-3741743cfdf3': 'Chuyên các chương trình giảm mỡ và săn chắc cơ thể. Josephine kết hợp bài sức mạnh, HIIT và hướng dẫn ăn uống cơ bản để bạn giữ dáng bền vững.',
};

const _trainerImages = {
  '30000000-0000-4000-8000-000000000001': 'assets/catalogue/pt_minh.jpg',
  '30000000-0000-4000-8000-000000000002': 'assets/catalogue/pt_lan.jpg',
  '031109d5-a072-4bf6-9916-3741743cfdf3': 'assets/catalogue/pt_josephine.jpg',
};

String rewardImage(String id, String url) => _rewardImages[id] ?? url;
String trainerImage(String id, String url) => _trainerImages[id] ?? url;
(String, String)? rewardCopy(String id) => _rewardCopy[id];

final _demoTag = RegExp(r'\s*\((demo|mẫu)\)\s*', caseSensitive: false);

/// Drops "(demo)" style tags left over from sample data.
String cleanName(String name) => name.replaceAll(_demoTag, ' ').trim();

/// Placeholder text such as "Dữ liệu mẫu cho module PT." counts as missing.
bool isPlaceholderText(String text) {
  final t = text.trim().toLowerCase();
  return t.isEmpty || t.contains('dữ liệu mẫu') || t.contains('demo');
}

String trainerIntro(String id, String description) =>
    isPlaceholderText(description) ? (_trainerIntros[id] ?? '') : description;

/// True for images shipped inside the app bundle.
bool isAssetImage(String url) => url.startsWith('assets/');
