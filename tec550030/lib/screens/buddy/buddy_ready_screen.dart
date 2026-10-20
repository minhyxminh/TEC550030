import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/buddy_profile.dart';
import '../../services/branch_service.dart';
import '../../services/buddy_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import 'buddy_onboarding_screen.dart';

class BuddyReadyScreen extends StatelessWidget {
  final BuddyProfile profile;
  final BuddyService buddyService;
  final BranchService branchService;
  final VoidCallback? onEdit;

  const BuddyReadyScreen({
    super.key,
    required this.profile,
    this.buddyService = const BuddyService(),
    this.branchService = const BranchService(),
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ Gym Buddy'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      size: 36,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Hồ sơ của bạn đã sẵn sàng!',
                    style: AppTextStyles.heading1,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profile.enabled
                        ? 'Bạn đang hiển thị trong danh sách tìm bạn tập.'
                        : 'Hồ sơ của bạn đang tạm ẩn.',
                    style: AppTextStyles.body.copyWith(
                      color: profile.enabled
                          ? AppColors.success
                          : AppColors.secondaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sở thích của bạn', style: AppTextStyles.heading2),
                  const SizedBox(height: 12),
                  if (profile.fitnessGoal != null) ...[
                    _InfoRow(
                      icon: Icons.flag_outlined,
                      label: 'Mục tiêu',
                      value: _goalLabel(profile.fitnessGoal!),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (profile.experienceLevel != null) ...[
                    _InfoRow(
                      icon: Icons.trending_up,
                      label: 'Trình độ',
                      value: _levelLabel(profile.experienceLevel!),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (profile.favoriteWorkouts.isNotEmpty) ...[
                    _InfoRow(
                      icon: Icons.fitness_center,
                      label: 'Bài tập',
                      value: profile.favoriteWorkouts.join(', '),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (profile.preferredWorkoutTimes.isNotEmpty) ...[
                    _InfoRow(
                      icon: Icons.access_time,
                      label: 'Khung giờ',
                      value: profile.preferredWorkoutTimes
                          .map(_timeLabel)
                          .join(', '),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _InfoRow(
                    icon: Icons.visibility_outlined,
                    label: 'Trạng thái',
                    value: profile.lookingForPartner
                        ? 'Đang tìm bạn tập'
                        : 'Không tìm lịch cụ thể',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              text: 'Chỉnh sửa sở thích',
              onPressed: onEdit ??
                  () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BuddyOnboardingScreen(
                            existingProfile: profile,
                            buddyService: buddyService,
                            branchService: branchService,
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  String _goalLabel(String goal) => switch (goal) {
        'MUSCLE_GAIN' => 'Tăng cơ',
        'FAT_LOSS' => 'Giảm mỡ',
        'MAINTAIN' => 'Giữ dáng',
        'STRENGTH' => 'Tăng sức mạnh',
        'HEALTH' => 'Cải thiện sức khỏe',
        _ => goal,
      };

  String _levelLabel(String level) => switch (level) {
        'BEGINNER' => 'Mới bắt đầu',
        'INTERMEDIATE' => 'Trung cấp',
        'ADVANCED' => 'Nâng cao',
        _ => level,
      };

  String _timeLabel(String time) => switch (time) {
        'MORNING' => 'Sáng',
        'NOON' => 'Trưa',
        'AFTERNOON' => 'Chiều',
        'EVENING' => 'Tối',
        _ => time,
      };
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primaryOrange),
        const SizedBox(width: 10),
        Text('$label: ', style: AppTextStyles.caption),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

