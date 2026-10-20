import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/buddy_profile.dart';
import '../../models/reward.dart';
import '../../models/user.dart';
import '../../services/account_service.dart';
import '../../services/branch_service.dart';
import '../../services/buddy_service.dart';
import '../../services/location_service.dart';
import '../../services/reward_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/catalogue_widgets.dart';
import '../../widgets/data_view.dart';
import '../../widgets/membership_summary.dart';
import '../buddy/buddy_onboarding_screen.dart';
import '../buddy/buddy_ready_screen.dart';
import '../rewards/reward_detail_screen.dart';
import '../../widgets/gym_panel.dart';
import 'branch_selection_screen.dart';

class _HomeData {
  final AccountOverview account;
  final List<Reward> rewards;
  final BuddyProfile? buddyProfile;
  const _HomeData(this.account, this.rewards, {this.buddyProfile});
}

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onSelectTab;
  final BranchService branchService;
  final LocationService locationService;
  final BuddyService buddyService;
  const HomeScreen({
    super.key,
    this.onSelectTab,
    this.branchService = const BranchService(),
    this.locationService = const LocationService(),
    this.buddyService = const BuddyService(),
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _version = 0;
  bool _busyBuddy = false;
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

  Future<void> _openBuddy(BuddyProfile? currentProfile, String? homeGymId) async {
    if (_busyBuddy) return;
    setState(() => _busyBuddy = true);
    try {
      final profile = currentProfile ?? await widget.buddyService.getProfile();
      if (!mounted) return;
      if (profile == null || !profile.onboardingCompleted) {
        final changed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => BuddyOnboardingScreen(
              existingProfile: profile,
              buddyService: widget.buddyService,
              branchService: widget.branchService,
              homeGymId: profile?.homeGymId ?? homeGymId,
            ),
          ),
        );
        if (changed == true && mounted) {
          setState(() => _version++);
        }
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BuddyReadyScreen(
              profile: profile,
              buddyService: widget.buddyService,
              branchService: widget.branchService,
              onEdit: () async {
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BuddyOnboardingScreen(
                      existingProfile: profile,
                      buddyService: widget.buddyService,
                      branchService: widget.branchService,
                      homeGymId: profile.homeGymId ?? homeGymId,
                    ),
                  ),
                );
                if (changed == true && mounted) {
                  setState(() => _version++);
                  Navigator.pop(context);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải thông tin: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyBuddy = false);
    }
  }

  Future<_HomeData> _load() async {
    final results = await Future.wait<Object?>([
      AccountService().getOverview(),
      RewardService().getRewards(),
      widget.buddyService.getProfile().catchError((_) => null),
    ]);
    return _HomeData(
      results[0] as AccountOverview,
      results[1] as List<Reward>,
      buddyProfile: results[2] as BuddyProfile?,
    );
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
            onTap: () => onSelectTab?.call(2),
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
            branchService: widget.branchService,
            onJoin: () => _join(data.account.user),
            onChanged: () => setState(() => _version++),
          ),
          const SizedBox(height: 24),
          AppCard(
            onTap: _busyBuddy ? null : () => _openBuddy(data.buddyProfile, data.account.user.homeGymId),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.people_outline,
                    color: AppColors.primaryOrange,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Kết nối bạn tập',
                            style: AppTextStyles.heading2,
                          ),
                          if (data.buddyProfile?.lookingForPartner == true) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Đang tìm bạn tập',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.buddyProfile?.onboardingCompleted == true
                            ? 'Khám phá những người phù hợp để tập cùng'
                            : 'Tìm người cùng lịch và cùng mục tiêu tập luyện',
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
