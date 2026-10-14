import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/reward.dart';
import '../../models/user.dart';
import '../../services/account_service.dart';
import '../../services/branch_service.dart';
import '../../services/location_service.dart';
import '../../services/reward_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/catalogue_widgets.dart';
import '../../widgets/data_view.dart';
import '../../widgets/membership_summary.dart';
import '../rewards/reward_detail_screen.dart';
import '../../widgets/gym_panel.dart';
import 'branch_selection_screen.dart';

class _HomeData {
  final AccountOverview account;
  final List<Reward> rewards;
  const _HomeData(this.account, this.rewards);
}

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onSelectTab;
  final BranchService branchService;
  final LocationService locationService;
  const HomeScreen({
    super.key,
    this.onSelectTab,
    this.branchService = const BranchService(),
    this.locationService = const LocationService(),
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _version = 0;
  void Function(int)? get onSelectTab => widget.onSelectTab;
  Future<void> _join(User user) async {
    if (user.homeGymId != null) {
      onSelectTab?.call(3);
      return;
    }
    final selected = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BranchSelectionScreen(
          branchService: widget.branchService,
          locationService: widget.locationService,
        ),
      ),
    );
    if (selected == true && mounted) setState(() => _version++);
  }

  Future<_HomeData> _load() async {
    final results = await Future.wait<Object>([
      AccountService().getOverview(),
      RewardService().getRewards(),
    ]);
    return _HomeData(results[0] as AccountOverview, results[1] as List<Reward>);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: DataView<_HomeData>(
        key: ValueKey(_version),
        load: _load,
        builder: (context, data) => [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chào bạn,', style: AppTextStyles.caption),
                    const SizedBox(height: 4),
                    Text(data.account.user.name, style: AppTextStyles.heading1),
                    const SizedBox(height: 6),
                    const Text(
                      'Sẵn sàng cho một ngày năng động?',
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => onSelectTab?.call(4),
                tooltip: 'Tài khoản',
                icon: const Icon(
                  Icons.account_circle_outlined,
                  size: 36,
                  color: AppColors.primaryOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          PointBalanceCard(
            balance: data.account.balance,
            onTap: () => onSelectTab?.call(1),
          ),
          const SizedBox(height: 24),
          const SectionTitle('Gói tập của bạn'),
          MembershipSummary(
            account: data.account,
            onTap: () => onSelectTab?.call(3),
          ),
          const SizedBox(height: 24),
          GymPanel(
            user: data.account.user,
            onJoin: () => _join(data.account.user),
            onChanged: () => setState(() => _version++),
          ),
          const SizedBox(height: 24),
          SectionTitle(
            'Khám phá phần quà',
            subtitle: '${data.rewards.length} phần quà trong danh mục',
            action: TextButton(
              onPressed: () => onSelectTab?.call(2),
              child: const Text('Xem tất cả'),
            ),
          ),
          if (data.rewards.isEmpty)
            const AppCard(
              child: Text(
                'Chưa có phần quà. Hãy quay lại sau nhé.',
                style: AppTextStyles.body,
              ),
            )
          else
            ...data.rewards
                .take(3)
                .map(
                  (reward) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RewardDetailScreen(id: reward.id),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: AppImage(url: reward.imageUrl),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reward.name,
                                  style: AppTextStyles.heading2,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${formatNumber(reward.points)} GP · ${reward.stock > 0 ? 'Còn ${formatNumber(reward.stock)} phần' : 'Hết quà'}',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.secondaryText,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}
