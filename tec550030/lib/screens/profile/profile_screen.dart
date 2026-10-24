import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/account_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/ambient.dart';
import '../../widgets/app_card.dart';
import '../../widgets/catalogue_widgets.dart';
import '../../widgets/data_view.dart';
import '../../widgets/decor.dart';
import '../../widgets/mascot.dart';
import '../../widgets/membership_summary.dart';
import '../../widgets/user_avatar.dart';
import 'activity_screen.dart';
import 'admin_screen.dart';
import 'edit_profile_screen.dart';
import '../../widgets/biometric_setting.dart';
import '../chat/chat_entry_screen.dart';

class ProfileScreen extends StatefulWidget {
  final ValueChanged<int>? onSelectTab;
  const ProfileScreen({super.key, this.onSelectTab});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _version = 0;
  void Function(int)? get onSelectTab => widget.onSelectTab;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageBackdrop(
      topBlob: AppColors.peach,
      child: SafeArea(
        bottom: false,
        child: DataView<AccountOverview>(
          key: ValueKey(_version),
          load: AccountService().getOverview,
          builder: (context, account) => [
            const PageHeader(
              title: 'Tài khoản',
              trailing: Padding(
                padding: EdgeInsets.only(right: 8),
                child: Sparkle(size: 18),
              ),
            ),
            _ProfileHeader(
              account: account,
              onEdit: () async {
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(
                      name: account.user.name,
                      avatarUrl: account.user.avatarUrl,
                    ),
                  ),
                );
                if (changed == true && mounted) setState(() => _version++);
              },
            ),
            const SizedBox(height: 20),
            PointBalanceCard(
              balance: account.balance,
              onTap: () => onSelectTab?.call(2),
            ),
            const SizedBox(height: 24),
            const SectionTitle('Gói tập của tôi'),
            MembershipSummary(
              account: account,
              onTap: () => onSelectTab?.call(3),
            ),
            const SizedBox(height: 20),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  _ProfileLink(
                    icon: Icons.receipt_long_rounded,
                    tint: const Color(0xFFB7791F),
                    background: AppColors.butter,
                    title: 'Lịch sử GymPoint',
                    subtitle: 'Các lần cộng và sử dụng điểm',
                    onTap: () => onSelectTab?.call(2),
                  ),
                  const _Divider(),
                  _ProfileLink(
                    icon: Icons.history_rounded,
                    tint: AppColors.purple,
                    background: AppColors.lavender,
                    title: 'Hoạt động của tôi',
                    subtitle: 'Buổi tập, đổi quà, đơn gói tập và lịch PT',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ActivityScreen()),
                    ),
                  ),
                  const _Divider(),
                  _ProfileLink(
                    icon: Icons.fitness_center_rounded,
                    tint: AppColors.strongOrange,
                    background: AppColors.peach,
                    title: 'Khám phá gói tập & PT',
                    onTap: () => onSelectTab?.call(3),
                  ),
                  if (account.user.role == 'ADMIN') ...[
                    const _Divider(),
                    _ProfileLink(
                      icon: Icons.admin_panel_settings_rounded,
                      tint: AppColors.info,
                      background: AppColors.infoSoft,
                      title: 'Quản trị phòng tập',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminScreen()),
                      ),
                    ),
                  ],
                  const _Divider(),
                  const BiometricSetting(embedded: true),
                  const _Divider(),
                  _ProfileLink(
                    icon: Icons.chat_bubble_rounded,
                    tint: Colors.white,
                    background: AppColors.purple,
                    title: account.user.role == 'ADMIN'
                        ? 'Hộp thư hỗ trợ'
                        : 'Chat với GymFlow',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatEntryScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              text: 'Đăng xuất',
              isSecondary: true,
              accent: AppColors.error,
              icon: Icons.logout_rounded,
              onPressed: () async {
                await AuthService().logout();
                if (!context.mounted) return;
                Navigator.of(
                  context,
                  rootNavigator: true,
                ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProfileHeader extends StatelessWidget {
  final AccountOverview account;
  final VoidCallback onEdit;
  const _ProfileHeader({required this.account, required this.onEdit});
  @override
  Widget build(BuildContext context) {
    final user = account.user;
    const banner = 118.0;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Purple banner with a dumbbell, sparkles and the tiger waving.
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
            child: Container(
              height: banner,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF9B80FF), AppColors.purple],
                ),
              ),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: AmbientBubbles(seed: 11, accents: false),
                  ),
                  Positioned(
                    left: 18,
                    top: 18,
                    child: Transform.rotate(
                      angle: -0.5,
                      child: Icon(
                        Icons.fitness_center_rounded,
                        size: 30,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 112,
                    top: 14,
                    child: Sparkle(
                      size: 14,
                      color: Colors.white,
                      outlined: false,
                    ),
                  ),
                  Positioned(
                    right: 98,
                    top: 30,
                    child: Squiggle(
                      width: 46,
                      color: Colors.white.withValues(alpha: 0.75),
                      stroke: 2.4,
                    ),
                  ),
                  const Positioned(
                    right: 6,
                    bottom: -6,
                    child: Mascot(
                      width: 92,
                      auraColor: Colors.white,
                      interactive: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, banner - 52, 20, 22),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.peach,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(27),
                          border: Border.all(color: AppColors.ink, width: 3),
                        ),
                        child: UserAvatar(
                          url: user.avatarUrl,
                          name: user.name,
                          radius: 44,
                          square: true,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          size: 17,
                          color: Color(0xFFFFD23F),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  style: AppTextStyles.heading1,
                  textAlign: TextAlign.center,
                ),
                Text(
                  user.email,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (user.createdAt != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lavender,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          size: 14,
                          color: AppColors.purple,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Thành viên từ ${formatDate(user.createdAt!)}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: 210,
                  child: AppButton(
                    text: 'Chỉnh sửa hồ sơ',
                    icon: Icons.edit_outlined,
                    leadingIcon: true,
                    dark: true,
                    onPressed: onEdit,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 72, endIndent: 16);
}

class _ProfileLink extends StatelessWidget {
  final IconData icon;
  final Color tint, background;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _ProfileLink({
    required this.icon,
    required this.tint,
    required this.background,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    leading: IconTile(icon, color: tint, background: background),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.ink),
    onTap: onTap,
  );
}
