import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/bmi_result.dart';
import '../../models/buddy_profile.dart';
import '../../models/machine_guide.dart';
import '../../models/mascot_mood.dart';
import '../../models/user.dart';
import '../../services/account_service.dart';
import '../../services/branch_service.dart';
import '../../services/buddy_service.dart';
import '../../services/gympoint_service.dart';
import '../../services/health_service.dart';
import '../../services/location_service.dart';
import '../../widgets/boss_banner.dart';
import '../../widgets/ambient.dart';
import '../../widgets/app_card.dart';
import '../../widgets/brand.dart';
import '../../widgets/catalogue_widgets.dart';
import '../../widgets/data_view.dart';
import '../../widgets/decor.dart';
import '../../widgets/gym_panel.dart';
import '../../widgets/machine_guide_card.dart';
import '../../widgets/mascot.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/user_avatar.dart';
import '../buddy/buddy_onboarding_screen.dart';
import '../buddy/buddy_swipe_screen.dart';
import '../guides/machine_guide_screen.dart';
import '../notifications/notifications_screen.dart';
import 'branch_selection_screen.dart';

class _HomeData {
  final AccountOverview account;
  final BuddyProfile? buddyProfile;
  final BmiResult? bmi;
  final int weeklyCheckins;
  const _HomeData(
    this.account, {
    this.buddyProfile,
    this.bmi,
    this.weeklyCheckins = 0,
  });
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

  Future<void> _openBuddy(
    BuddyProfile? currentProfile,
    String? homeGymId,
  ) async {
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
            builder: (_) => BuddySwipeScreen(
              profile: profile,
              buddyService: widget.buddyService,
              branchService: widget.branchService,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể tải thông tin: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyBuddy = false);
    }
  }

  Future<_HomeData> _load() async {
    final results = await Future.wait<Object?>([
      AccountService().getOverview(),
      widget.buddyService.getProfile().catchError((_) => null),
      GymPointService()
          .getHistory(limit: 30)
          .then<Object?>((h) => weeklyCheckinDays(h))
          .catchError((_) => 0),
    ]);
    final account = results[0] as AccountOverview;
    BmiResult? bmi;
    try {
      bmi = (await HealthService().overview(account.user.id)).result;
    } catch (_) {
      /* The summary simply omits health when local data is unreadable. */
    }
    return _HomeData(
      account,
      buddyProfile: results[1] as BuddyProfile?,
      bmi: bmi,
      weeklyCheckins: results[2] as int,
    );
  }

  void _openGuide(MachineGuide guide) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => MachineGuideScreen(guide: guide)),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageBackdrop(
      child: SafeArea(
        bottom: false,
        child: DataView<_HomeData>(
          key: ValueKey(_version),
          load: _load,
          builder: (context, data) => [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        'Chào bạn,',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.secondaryText,
                          fontSize: 15,
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: GlowTitle(
                              data.account.user.name,
                              fontSize: 34,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 150, top: 2),
                        child: Sparkle(size: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 10),
                  child: NotificationBell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Tài khoản',
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.peach,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: AppShadows.soft,
                    ),
                    child: Material(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => onSelectTab?.call(4),
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: data.account.user.avatarUrl == null
                              ? const Icon(
                                  Icons.person_outline_rounded,
                                  color: Colors.white,
                                )
                              : Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: UserAvatar(
                                    url: data.account.user.avatarUrl,
                                    radius: 22,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _WelcomeCard(
              data: data,
              onHealth: () => onSelectTab?.call(1),
              onPoints: () => onSelectTab?.call(2),
              onMembership: () => onSelectTab?.call(3),
            ),
            const SizedBox(height: AppSpacing.lg),
            const BossBanner(),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.favorite_outline_rounded,
                    label: 'Theo dõi sức khỏe',
                    color: AppColors.success,
                    background: AppColors.mint,
                    onTap: () => onSelectTab?.call(1),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.calendar_month_rounded,
                    label: 'Xem lịch tập',
                    color: AppColors.purple,
                    background: AppColors.lavender,
                    onTap: () => onSelectTab?.call(3),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.redeem_rounded,
                    label: 'Đổi thưởng',
                    color: AppColors.strongOrange,
                    background: AppColors.peach,
                    onTap: () => onSelectTab?.call(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.section),
            GymPanel(
              user: data.account.user,
              branchService: widget.branchService,
              onJoin: () => _join(data.account.user),
              onChanged: () => setState(() => _version++),
            ),
            const SizedBox(height: AppSpacing.section),
            const SectionTitle(
              'Gym Buddy',
              subtitle: 'Tập cùng bạn, có động lực hơn',
            ),
            _BuddyCard(
              profile: data.buddyProfile,
              busy: _busyBuddy,
              onTap: () =>
                  _openBuddy(data.buddyProfile, data.account.user.homeGymId),
            ),
            const SizedBox(height: AppSpacing.section),
            SectionTitle(
              'Bài tập nổi bật',
              subtitle: 'Video ngắn giúp bạn tập đúng kỹ thuật',
              action: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MachineGuideListScreen(),
                  ),
                ),
                child: const Text('Xem tất cả'),
              ),
            ),
            SizedBox(
              height: MediaQuery.textScalerOf(context)
                  .scale(304)
                  .clamp(304, 384),
              child: ListView.separated(
                key: const ValueKey('machine-guides'),
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: machineGuides.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (_, i) => MachineGuideCard(
                  guide: machineGuides[i],
                  onTap: () => _openGuide(machineGuides[i]),
                  onWatch: () => watchGuide(context, machineGuides[i]),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: Opacity(
                opacity: 0.8,
                child: Image.asset(
                  'assets/brand/tagline.png',
                  height: 16,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _WelcomeCard extends StatelessWidget {
  final _HomeData data;
  final VoidCallback onHealth, onPoints, onMembership;
  const _WelcomeCard({
    required this.data,
    required this.onHealth,
    required this.onPoints,
    required this.onMembership,
  });

  @override
  Widget build(BuildContext context) {
    final user = data.account.user;
    final bmi = data.bmi;
    // Greets the member; cheers when the weekly goal is met, naps at night.
    final mood = data.weeklyCheckins >= weeklyCheckinGoal
        ? MascotMood.celebrate
        : isRestHour()
        ? MascotMood.sleeping
        : MascotMood.neutral;
    final plans = data.account.memberships.where(
      (m) => m.id == user.activeMembershipId,
    );
    final membership = user.activeMembershipId == null
        ? 'Chưa có gói tập'
        : plans.isEmpty
        ? 'Gói tập'
        : plans.first.name;
    final daysLeft = user.membershipExpiresAt
        ?.difference(DateTime.now())
        .inDays;
    final membershipNote = user.activeMembershipId == null
        ? null
        : !user.hasActiveMembership
        ? ' · hết hạn'
        : daysLeft != null && daysLeft >= 0 && daysLeft <= 60
        ? ' · còn $daysLeft ngày'
        : null;
    return RingFrame(
      color: AppColors.primaryOrange.withValues(alpha: 0.22),
      width: 7,
      child: HighlightCard(
        gradient: AppColors.brandGradient,
        glow: AppColors.primaryOrange,
        accents: true,
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                    width: 2,
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 168,
              top: 22,
              child: Sparkle(size: 12, color: Colors.white, outlined: false),
            ),
            const Positioned(
              right: 10,
              top: 26,
              child: Sparkle(size: 10, color: AppColors.ink, outlined: false),
            ),
            Positioned(
              right: -4,
              bottom: 2,
              child: Mascot(mood: mood, width: 132, auraColor: Colors.white),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 120, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const InkChip('HÔM NAY', icon: Icons.bolt_rounded),
                  const SizedBox(height: 10),
                  Text(
                    'Sẵn sàng cho một ngày năng động?',
                    style: AppTextStyles.heading1.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _WeeklyProgress(days: data.weeklyCheckins),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _SummaryPill(
                        icon: Icons.fitness_center_rounded,
                        text: membership,
                        suffix: membershipNote,
                        onTap: onMembership,
                      ),
                      _SummaryPill(
                        icon: Icons.favorite_outline_rounded,
                        text: bmi == null
                            ? 'Chưa có BMI'
                            : 'BMI ${bmi.bmi.toStringAsFixed(1)}',
                        onTap: onHealth,
                      ),
                      _SummaryPill(
                        icon: Icons.stars_rounded,
                        text: formatNumber(data.account.balance),
                        suffix: ' GP',
                        dark: true,
                        onTap: onPoints,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyProgress extends StatelessWidget {
  final int days;
  const _WeeklyProgress({required this.days});
  @override
  Widget build(BuildContext context) {
    final done = days.clamp(0, weeklyCheckinGoal);
    final style = AppTextStyles.caption.copyWith(
      color: AppColors.ink,
      fontWeight: FontWeight.w600,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Mục tiêu tuần', style: style)),
            Text('$done/$weeklyCheckinGoal buổi tập', style: style),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < weeklyCheckinGoal; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 8,
                  decoration: BoxDecoration(
                    color: i < done
                        ? AppColors.ink
                        : AppColors.ink.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              if (i < weeklyCheckinGoal - 1) const SizedBox(width: 4),
            ],
          ],
        ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? suffix;
  final bool dark;
  final VoidCallback onTap;
  const _SummaryPill({
    required this.icon,
    required this.text,
    this.suffix,
    this.dark = false,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.caption.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: dark ? Colors.white : AppColors.ink,
    );
    return Material(
      color: dark ? AppColors.ink : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: dark ? AppColors.gymPointYellow : AppColors.ink,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  text,
                  style: style,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (suffix != null)
                Text(
                  suffix!,
                  style: style.copyWith(fontWeight: FontWeight.w500),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, background;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
  });
  // Tinted tile, white icon square and a darker "block" edge underneath.
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.28),
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              right: -18,
              top: -18,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 18),
              child: Column(
                children: [
                  IconTile(
                    icon,
                    color: color,
                    background: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: AppTextStyles.title.copyWith(
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BuddyCard extends StatelessWidget {
  final BuddyProfile? profile;
  final bool busy;
  final VoidCallback onTap;
  const _BuddyCard({
    required this.profile,
    required this.busy,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => AppCard(
    onTap: busy ? null : onTap,
    color: AppColors.lavender,
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        SizedBox(
          width: 70,
          height: 52,
          child: Stack(
            children: [
              _avatar(0, 0, AppColors.purple),
              _avatar(24, 10, AppColors.primaryOrange),
              const Positioned(left: 44, top: 0, child: TigerHead(size: 24)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kết nối bạn tập',
                style: AppTextStyles.heading2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (profile?.lookingForPartner == true) ...[
                const SizedBox(height: 6),
                const StatusPill(
                  'Đang tìm bạn tập',
                  color: AppColors.success,
                  background: AppColors.mint,
                ),
              ],
              const SizedBox(height: 4),
              Text(
                profile?.onboardingCompleted == true
                    ? 'Khám phá những người phù hợp để tập cùng'
                    : 'Tìm người cùng lịch và cùng mục tiêu tập luyện',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: AppColors.ink,
            shape: BoxShape.circle,
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
        ),
      ],
    ),
  );

  Widget _avatar(double left, double top, Color color) => Positioned(
    left: left,
    top: top,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.lavender, width: 3),
      ),
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
    ),
  );
}
