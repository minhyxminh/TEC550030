import 'bmi_result.dart';
import 'point_transaction.dart';

enum MascotMood {
  neutral,
  happy,
  strong,
  tired,
  underweight,
  thinking,
  celebrate,
  sleeping,
}

// Copy stays encouraging and never comments on the user's body.
class MascotMoodInfo {
  final String label, message;
  const MascotMoodInfo(this.label, this.message);
}

const weeklyCheckinGoal = 3;

extension MascotMoodCopy on MascotMood {
  MascotMoodInfo get info => switch (this) {
    MascotMood.neutral => const MascotMoodInfo(
      'Sẵn sàng',
      'Tập vui, khỏe đều mỗi ngày!',
    ),
    MascotMood.happy => const MascotMoodInfo(
      'Phong độ tốt',
      'Chỉ số đang rất ổn! Giữ nhịp ăn ngủ và tập luyện đều như vậy nhé.',
    ),
    MascotMood.strong => const MascotMoodInfo(
      'Sung sức',
      'Bạn đang tập rất đều tay. Sức bền và sức mạnh đang lên đấy!',
    ),
    MascotMood.tired => const MascotMoodInfo(
      'Cùng cải thiện',
      'Từng bước nhỏ là đủ. Hôm nay mình cùng đi bộ 15 phút và uống đủ nước nhé?',
    ),
    MascotMood.underweight => const MascotMoodInfo(
      'Nạp thêm năng lượng',
      'Thêm một bữa phụ giàu đạm và vài bài sức mạnh nhẹ, cơ thể sẽ khỏe dần lên.',
    ),
    MascotMood.thinking => const MascotMoodInfo(
      'Chờ dữ liệu',
      'Cho mình biết chiều cao và cân nặng nhé, mình sẽ gợi ý lộ trình hợp với bạn!',
    ),
    MascotMood.celebrate => const MascotMoodInfo(
      'Đạt mục tiêu tuần',
      'Tuyệt vời! Bạn đã tập đủ $weeklyCheckinGoal buổi tuần này. Nghỉ ngơi xứng đáng nhé!',
    ),
    MascotMood.sleeping => const MascotMoodInfo(
      'Nghỉ ngơi',
      'Ngủ đủ giấc giúp cơ phục hồi. Mai mình lại tập tiếp nhé!',
    ),
  };
}

/// Distinct Vietnam-time days with a gym check-in during the last 7 days.
/// Late evening or early morning in Vietnam time, when the tiger naps.
bool isRestHour([DateTime? now]) {
  final hour = (now ?? DateTime.now())
      .toUtc()
      .add(const Duration(hours: 7))
      .hour;
  return hour >= 22 || hour < 5;
}

int weeklyCheckinDays(List<PointTransaction> history, {DateTime? now}) {
  final today = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
  final start = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).subtract(const Duration(days: 6));
  final days = <String>{};
  for (final tx in history) {
    if (tx.type != 'EARN' || !tx.reason.startsWith('Check-in')) continue;
    final local = tx.createdAt.toUtc().add(const Duration(hours: 7));
    if (local.isBefore(start)) continue;
    days.add('${local.year}-${local.month}-${local.day}');
  }
  return days.length;
}

MascotMood moodForHealth(BmiResult? result, {int weeklyCheckins = 0}) {
  if (result == null) return MascotMood.thinking;
  if (weeklyCheckins >= weeklyCheckinGoal) return MascotMood.celebrate;
  return switch (result.categoryIndex) {
    0 => MascotMood.underweight,
    1 => weeklyCheckins >= 2 ? MascotMood.strong : MascotMood.happy,
    _ => MascotMood.tired,
  };
}
