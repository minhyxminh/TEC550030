import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/reward.dart';
import '../../services/reward_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/catalogue_widgets.dart';
import '../../widgets/data_view.dart';
import '../../widgets/decor.dart';
import '../../widgets/empty_state.dart';
import 'reward_detail_screen.dart';
import '../../models/gympoint.dart';
import '../../services/gympoint_service.dart';
import '../gympoint/gympoint_screen.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});
  Future<(List<Reward>, GymPointBalance)> _load() async {
    final data = await Future.wait<Object>([
      RewardService().getRewards(),
      GymPointService().getBalance(),
    ]);
    return (data[0] as List<Reward>, data[1] as GymPointBalance);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageBackdrop(
      topBlob: AppColors.peach,
      child: SafeArea(
        bottom: false,
        child: DataView<(List<Reward>, GymPointBalance)>(
          load: _load,
          builder: (context, data) {
            final rewards = data.$1;
            return [
              const PageHeader(
                title: 'Đổi thưởng',
                subtitle: 'Dùng GymPoint đổi quà bạn thích',
                trailing: Sparkle(size: 18),
              ),
              PointBalanceCard(
                balance: data.$2.balance,
                onHistory: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GymPointScreen()),
                ),
              ),
              const SizedBox(height: 24),
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
                      children: rewards.indexed
                          .map(
                            (entry) => SizedBox(
                              width: width,
                              child: _RewardTile(
                                reward: entry.$2,
                                tint: entry.$1,
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              const SizedBox(height: 80),
            ];
          },
        ),
      ),
    ),
  );
}

class _RewardTile extends StatelessWidget {
  final Reward reward;
  final int tint;
  const _RewardTile({required this.reward, required this.tint});
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(10),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RewardDetailScreen(id: reward.id)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.35,
          child: AppImage(
            url: reward.imageUrl,
            tint: tint,
            icon: _iconFor(reward.name),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reward.name,
                style: AppTextStyles.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${formatNumber(reward.points)} GP',
                style: AppTextStyles.heading2.copyWith(
                  color: AppColors.deepOrange,
                ),
              ),
              const SizedBox(height: 6),
              StatusPill(
                reward.stock > 0
                    ? 'Còn ${formatNumber(reward.stock)} phần'
                    : 'Hết quà',
                color: reward.stock > 0 ? AppColors.success : AppColors.error,
                background: reward.stock > 0 ? AppColors.mint : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Xem chi tiết',
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.ink,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // Placeholder icon only; real images replace it when the catalogue has one.
  static IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('nước')) return Icons.water_drop_outlined;
    if (n.contains('protein') || n.contains('bánh')) {
      return Icons.cookie_outlined;
    }
    if (n.contains('khăn')) return Icons.dry_cleaning_outlined;
    if (n.contains('voucher') || n.contains('đồ uống')) {
      return Icons.local_cafe_outlined;
    }
    return Icons.card_giftcard_rounded;
  }
}
