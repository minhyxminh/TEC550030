import 'package:flutter/material.dart';

import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import '../../widgets/app_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  User? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    // Không dùng API theo yêu cầu
    setState(() {
      _user = User(id: '1', email: 'member@gymflow.com', name: 'Nguyễn Văn A');
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryOrange),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primaryOrange,
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _user?.name ?? 'Người dùng',
                    style: AppTextStyles.heading1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _user?.email ?? '',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 48),

                  ListTile(
                    leading: const Icon(
                      Icons.history,
                      color: AppColors.darkText,
                    ),
                    title: const Text(
                      'Lịch sử hoạt động',
                      style: AppTextStyles.heading2,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Navigate to history
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.card_membership,
                      color: AppColors.darkText,
                    ),
                    title: const Text(
                      'Gói tập của tôi',
                      style: AppTextStyles.heading2,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Navigate to membership details
                    },
                  ),
                  const Divider(),

                  const SizedBox(height: 48),
                  AppButton(
                    text: 'Đăng xuất',
                    isSecondary: true,
                    onPressed: _logout,
                  ),
                ],
              ),
            ),
    );
  }
}
