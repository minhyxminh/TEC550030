import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/reward.dart';
import '../../services/reward_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/catalogue_widgets.dart';
import '../../widgets/data_view.dart';
import '../../widgets/empty_state.dart';
import 'reward_detail_screen.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đổi thưởng')),
    body: DataView<List<Reward>>(
      load: RewardService().getRewards,
      builder: (context, rewards) => [
        SectionTitle(
          'Quà dành cho bạn',
          subtitle: '${rewards.length} phần quà · Chạm để xem chi tiết',
        ),
        if (rewards.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: EmptyState(
              message: 'Chưa có phần quà. Hãy quay lại sau nhé.',
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 320
                  ? 1
                  : constraints.maxWidth < 650
                  ? 2
                  : 3;
              final width =
                  (constraints.maxWidth - 12 * (columns - 1)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 16,
                children: rewards
                    .map(
                      (reward) => SizedBox(
                        width: width,
                        child: AppCard(
                          padding: const EdgeInsets.all(12),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RewardDetailScreen(id: reward.id),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 1.3,
                                child: AppImage(url: reward.imageUrl),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                reward.name,
                                style: AppTextStyles.heading2,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${formatNumber(reward.points)} GP',
                                style: AppTextStyles.heading2.copyWith(
                                  color: AppColors.deepOrange,
                                ),
                              ),
                              const SizedBox(height: 8),
                              StatusPill(
                                reward.stock > 0
                                    ? 'Còn ${formatNumber(reward.stock)} phần'
                                    : 'Hết quà',
                                color: reward.stock > 0
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Xem chi tiết',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    ),
  );
}
