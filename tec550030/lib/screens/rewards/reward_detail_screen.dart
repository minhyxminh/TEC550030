import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/mascot_mood.dart';
import '../../models/reward.dart';
import '../../services/reward_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/catalogue_widgets.dart';
import '../../widgets/data_view.dart';
import '../../widgets/mascot.dart';
import '../../widgets/workflow_button.dart';

class RewardDetailScreen extends StatelessWidget {
  final String id;
  const RewardDetailScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết phần quà')),
    body: DataView<Reward>(
      load: () => RewardService().getRewardDetails(id),
      builder: (context, reward) => [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: AppImage(url: reward.imageUrl),
        ),
        const SizedBox(height: 20),
        Text(reward.name, style: AppTextStyles.heading1),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              '${formatNumber(reward.points)} GymPoint',
              color: AppColors.deepOrange,
            ),
            StatusPill(
              reward.stock > 0
                  ? 'Còn ${formatNumber(reward.stock)} phần'
                  : 'Hết quà',
              color: reward.stock > 0 ? AppColors.success : AppColors.error,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SectionTitle('Thông tin phần quà'),
        AppCard(
          child: Text(
            reward.description.isEmpty
                ? 'Phần quà chưa có mô tả.'
                : reward.description,
            style: AppTextStyles.body,
          ),
        ),
        const SizedBox(height: 24),
        const AppCard(
          child: Text(
            'Sau khi đổi, điểm và số lượng quà được cập nhật ngay. Mang mã đổi quà trong Hoạt động của tôi đến quầy để nhận.',
          ),
        ),
        const SizedBox(height: 16),
        if (reward.stock > 0)
          RequestButton(
            path: '/redemptions',
            body: {'reward_id': reward.id},
            text: 'Đổi quà',
            confirmation:
                'Dùng ${formatNumber(reward.points)} GP để đổi ${reward.name}?',
            success: 'Đã đổi quà. Xem mã nhận trong Hoạt động của tôi.',
            onSuccess: () => showMascotToast(
              context,
              mood: MascotMood.happy,
              message: 'Đổi quà thành công! Chúc bạn tập vui.',
            ),
          )
        else
          const AppButton(text: 'Tạm hết quà'),
      ],
    ),
  );
}
