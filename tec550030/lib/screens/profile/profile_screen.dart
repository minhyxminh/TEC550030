import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/account_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/catalogue_widgets.dart';
import '../../widgets/data_view.dart';
import '../../widgets/membership_summary.dart';
import '../../widgets/user_avatar.dart';
import 'activity_screen.dart';
import 'admin_screen.dart';
import 'edit_profile_screen.dart';

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
    appBar: AppBar(title: const Text('Tài khoản')),
    body: DataView<AccountOverview>(
      key: ValueKey(_version),
      load: AccountService().getOverview,
      builder: (context, account) => [
        AppCard(
          child: Column(
            children: [
              UserAvatar(url: account.user.avatarUrl),
              const SizedBox(height: 16),
              Text(
                account.user.name,
                style: AppTextStyles.heading1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () async {
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
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Chỉnh sửa hồ sơ'),
              ),
              Text(
                account.user.email,
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              if (account.user.createdAt != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Thành viên từ ${formatDate(account.user.createdAt!)}',
                  style: AppTextStyles.caption,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        PointBalanceCard(
          balance: account.balance,
          onTap: () => onSelectTab?.call(1),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Gói tập của tôi'),
        MembershipSummary(account: account, onTap: () => onSelectTab?.call(3)),
        const SizedBox(height: 24),
        _ProfileLink(
          icon: Icons.receipt_long_outlined,
          title: 'Lịch sử GymPoint',
          subtitle: 'Các lần cộng và sử dụng điểm',
          onTap: () => onSelectTab?.call(1),
        ),
        const SizedBox(height: 16),
        _ProfileLink(
          icon: Icons.history,
          title: 'Hoạt động của tôi',
          subtitle: 'Buổi tập, đổi quà, đơn gói tập và lịch PT',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ActivityScreen()),
          ),
        ),
        const SizedBox(height: 16),
        _ProfileLink(
          icon: Icons.fitness_center,
          title: 'Khám phá gói tập & PT',
          onTap: () => onSelectTab?.call(3),
        ),
        if (account.user.role == 'ADMIN') ...[
          const SizedBox(height: 16),
          _ProfileLink(
            icon: Icons.admin_panel_settings,
            title: 'Quản trị phòng tập',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminScreen()),
            ),
          ),
        ],
        const SizedBox(height: 24),
        AppButton(
          text: 'Đăng xuất',
          isSecondary: true,
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
  );
}

class _ProfileLink extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _ProfileLink({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: ListTile(
      leading: Icon(icon, color: AppColors.primaryOrange),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
