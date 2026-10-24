import 'package:material_ui/material_ui.dart';

enum GuideLevel { beginner, intermediate }

extension GuideLevelLabel on GuideLevel {
  String get label => this == GuideLevel.beginner ? 'Beginner' : 'Intermediate';
}

class MachineGuide {
  final String id, name, subtitle;
  final Duration duration;
  final List<String> muscles;
  final GuideLevel level;
  final IconData icon;
  final List<Color> colors;
  final List<String> setup, steps, mistakes;
  final String prescription;
  final String? videoUrl;

  /// YouTube video id; the cover image is derived from it.
  final String? youtubeId;

  const MachineGuide({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.duration,
    required this.muscles,
    required this.level,
    required this.icon,
    required this.colors,
    required this.setup,
    required this.steps,
    required this.mistakes,
    required this.prescription,
    this.videoUrl,
    this.youtubeId,
  });

  String? get thumbnailUrl => youtubeId == null
      ? null
      : 'https://i.ytimg.com/vi/$youtubeId/hqdefault.jpg';

  String get durationLabel {
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

const machineGuides = [
  MachineGuide(
    id: 'side-plank-twist',
    name: 'Plank lắc hông',
    subtitle: 'Side-to-side plank cho vùng bụng',
    duration: Duration(seconds: 10),
    muscles: ['Cơ bụng', 'Cơ liên sườn', 'Vai'],
    level: GuideLevel.beginner,
    icon: Icons.self_improvement_rounded,
    colors: [Color(0xFF2C2840), Color(0xFF1E1B2E)],
    youtubeId: 'DbONzJwBT8M',
    videoUrl: 'https://youtube.com/shorts/DbONzJwBT8M',
    setup: [
      'Trải thảm, chống hai cẳng tay xuống sàn, khuỷu tay ngay dưới vai.',
      'Duỗi thẳng chân, đầu, lưng và hông thành một đường thẳng.',
    ],
    steps: [
      'Siết bụng và mông, giữ vai cố định.',
      'Xoay hông nghiêng sang một bên cho hông tiến gần sàn, rồi trở về giữa.',
      'Đổi sang bên còn lại, nhịp đều và có kiểm soát, thở đều trong suốt bài.',
    ],
    mistakes: [
      'Võng lưng dưới hoặc đẩy mông lên quá cao.',
      'Lắc nhanh bằng đà khiến vai và cổ tay bị dồn lực.',
    ],
    prescription: '25 lần × 5 hiệp',
  ),
  MachineGuide(
    id: 'beginner-tabata',
    name: 'Tabata cho người mới',
    subtitle: 'Cardio toàn thân, bắt đầu với Slow Jumping Jack',
    duration: Duration(minutes: 1),
    muscles: ['Toàn thân', 'Tim mạch', 'Chân'],
    level: GuideLevel.beginner,
    icon: Icons.directions_run_rounded,
    colors: [Color(0xFF9B80FF), Color(0xFF7457F0)],
    youtubeId: 'BfS2eauwPTs',
    videoUrl: 'https://youtube.com/shorts/BfS2eauwPTs',
    setup: [
      'Chọn khoảng trống đủ rộng để dang tay chân, mang giày có đệm.',
      'Khởi động khớp cổ chân, gối và vai khoảng 3–5 phút.',
    ],
    steps: [
      'Tập mỗi động tác 20 giây với nhịp vừa sức, nghỉ 10 giây.',
      'Với Slow Jumping Jack, bước chân sang ngang thay vì bật nhảy, đưa tay lên cao.',
      'Lặp lại đủ 8 lượt (4 phút), sau đó đi bộ nhẹ để hạ nhịp tim.',
    ],
    mistakes: [
      'Cố tăng tốc ngay từ đầu rồi hụt hơi ở các lượt cuối.',
      'Tiếp đất bằng gót chân và khóa thẳng gối.',
    ],
    prescription: '20 giây tập / 10 giây nghỉ × 8 lượt',
  ),
  MachineGuide(
    id: 'dumbbell-upper-body',
    name: 'Thân trên với tạ đơn',
    subtitle: '8 bài cho vai và tay săn chắc',
    duration: Duration(seconds: 15),
    muscles: ['Vai', 'Tay trước', 'Tay sau'],
    level: GuideLevel.beginner,
    icon: Icons.fitness_center_rounded,
    colors: [Color(0xFFFF9A63), Color(0xFFFF7A3D)],
    youtubeId: 'JAUtSHs53j4',
    videoUrl: 'https://youtube.com/shorts/JAUtSHs53j4',
    setup: [
      'Chọn cặp tạ đơn nhẹ để làm đủ số lần mà vẫn giữ đúng tư thế.',
      'Đứng hoặc ngồi thẳng lưng, siết nhẹ cơ bụng.',
    ],
    steps: [
      'Làm lần lượt từng bài trong video, mỗi bài 10–12 lần.',
      'Nâng tạ trong 1–2 giây và hạ chậm trong 2–3 giây.',
      'Nghỉ 30–45 giây giữa các bài, lặp lại cả chuỗi 2–3 vòng.',
    ],
    mistakes: [
      'Vung tạ bằng đà lưng thay vì dùng lực vai và tay.',
      'Nhún vai lên tai hoặc gập cổ tay khi cầm tạ.',
    ],
    prescription: '8 bài × 10–12 lần, 2–3 vòng',
  ),
  MachineGuide(
    id: 'leg-press-variations',
    name: 'Leg Press',
    subtitle: 'Đổi vị trí chân để nhắm đúng nhóm cơ',
    duration: Duration(seconds: 18),
    muscles: ['Đùi trước', 'Mông', 'Đùi trong'],
    level: GuideLevel.intermediate,
    icon: Icons.airline_seat_legroom_extra_rounded,
    colors: [Color(0xFF2C2840), Color(0xFF1E1B2E)],
    youtubeId: 'BnacvXdaxq8',
    videoUrl: 'https://youtube.com/shorts/BnacvXdaxq8',
    setup: [
      'Ngồi sát lưng vào đệm, hông và lưng dưới không rời ghế.',
      'Chân cao trên bàn đạp: mông làm việc nhiều hơn. Chân thấp: đùi trước nhiều hơn.',
      'Chân rộng: đùi trong và mông. Chân khép gần nhau: phần ngoài đùi trước.',
    ],
    steps: [
      'Đẩy bàn đạp lên và mở khóa an toàn.',
      'Hạ chậm đến khi gối gập khoảng 90°, đầu gối đi cùng hướng mũi chân.',
      'Đẩy bằng cả bàn chân để đưa bàn đạp lên, không khóa thẳng gối ở cuối.',
    ],
    mistakes: [
      'Hạ quá sâu làm hông cuộn khỏi ghế.',
      'Khóa gối thẳng hoàn toàn khi đẩy lên.',
    ],
    prescription: '3 hiệp × 10–15 lần, nghỉ 90 giây',
  ),
  MachineGuide(
    id: 'dumbbell-squat',
    name: 'Squat tạ đơn',
    subtitle: '3 biến thể cho đùi và mông',
    duration: Duration(seconds: 19),
    muscles: ['Đùi trước', 'Mông', 'Cơ lõi'],
    level: GuideLevel.beginner,
    icon: Icons.accessibility_new_rounded,
    colors: [Color(0xFF9B80FF), Color(0xFF7457F0)],
    youtubeId: 'xtRkNVQidDE',
    videoUrl: 'https://youtube.com/shorts/xtRkNVQidDE',
    setup: [
      'Đứng hai chân rộng bằng hoặc hơn vai, mũi chân hơi mở.',
      'Giữ tạ trước ngực hoặc hai bên thân, ngực mở.',
    ],
    steps: [
      'Đẩy hông ra sau và gập gối như ngồi xuống ghế.',
      'Hạ đến khi đùi gần song song sàn, lưng thẳng, gót chân bám sàn.',
      'Đạp gót chân để đứng lên, siết mông ở cuối động tác.',
    ],
    mistakes: [
      'Đầu gối đổ vào trong khi lên xuống.',
      'Nhón gót hoặc gù lưng khi hạ thấp.',
    ],
    prescription: '3 hiệp × 12 lần mỗi biến thể',
  ),
];
