import 'package:material_ui/material_ui.dart';

import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/ambient.dart';
import '../../widgets/brand.dart';
import '../../widgets/mascot.dart';
import '../../services/auth_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _remember = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _remember = prefs.getBool('remember_login') ?? true;
      if (_emailController.text.isEmpty) {
        _emailController.text = prefs.getString('remembered_email') ?? '';
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _authService.login(
        _emailController.text,
        _passwordController.text,
        remember: _remember,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.mainLayout,
        (_) => false,
      );
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LoginHeader(top: MediaQuery.paddingOf(context).top),
              Transform.translate(
                offset: const Offset(0, -28),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Chào mừng đến với GymFlow',
                        style: AppTextStyles.heading1,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Đăng nhập để tiếp tục',
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: 24),
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      AppInput(
                        label: 'Email',
                        hint: 'Nhập email của bạn',
                        controller: _emailController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập email';
                          }
                          if (!value.contains('@')) {
                            return 'Email không hợp lệ';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AppInput(
                        label: 'Mật khẩu',
                        hint: 'Nhập mật khẩu',
                        controller: _passwordController,
                        isPassword: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập mật khẩu';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            // The sheet is a plain box; ink needs a Material.
                            child: Material(
                              type: MaterialType.transparency,
                              child: CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: const Text(
                                  'Ghi nhớ đăng nhập',
                                  style: AppTextStyles.title,
                                ),
                                subtitle: const Text(
                                  'Bỏ chọn: đăng nhập lại khi mở ứng dụng sau khi đã đóng.',
                                ),
                                value: _remember,
                                onChanged: _isLoading
                                    ? null
                                    : (value) => setState(
                                        () => _remember = value ?? false,
                                      ),
                              ),
                            ),
                          ),
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  textStyle: AppTextStyles.title.copyWith(
                                    fontSize: 13,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                onPressed: _isLoading
                                    ? null
                                    : () => Navigator.pushNamed(
                                        context,
                                        AppRoutes.forgotPassword,
                                      ),
                                child: const Text('Quên mật khẩu?'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        text: 'Đăng nhập',
                        icon: Icons.arrow_forward_rounded,
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _login,
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          Text(
                            'Chưa có tài khoản? ',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.secondaryText,
                            ),
                          ),
                          GestureDetector(
                            onTap: _isLoading
                                ? null
                                : () {
                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.register,
                                    );
                                  },
                            child: Text(
                              'Đăng ký ngay',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.deepOrange,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.deepOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Orange brand header with the logo, mascot and drifting bubbles.
class _LoginHeader extends StatelessWidget {
  final double top;
  const _LoginHeader({required this.top});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(48)),
    child: Container(
      height: 300 + top,
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      child: Stack(
        children: [
          const Positioned.fill(child: AmbientBubbles(seed: 3)),
          Positioned(
            left: 0,
            right: 0,
            top: top + 18,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AppShadows.soft,
                ),
                child: const GymFlowWordmark(height: 28),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 34,
            child: Center(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [const Mascot(width: 160, auraColor: Colors.white)],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
