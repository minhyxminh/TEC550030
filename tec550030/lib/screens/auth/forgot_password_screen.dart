import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/api/api_client.dart';
import '../../core/navigation/app_routes.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _sentEmail;
  String? _error;
  bool _busy = false;
  bool _done = false;
  int _seconds = 0;
  Timer? _timer;
  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy ||
        _seconds > 0 ||
        (_sentEmail == null && !_form.currentState!.validate())) {
      return;
    }
    final email = _email.text.trim().toLowerCase();
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiClient.postJson('/auth/forgot-password', {
        'email': email,
      }, authenticated: false);
      if (!mounted) return;
      setState(() {
        _sentEmail = email;
        _seconds = 60;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _seconds--);
        if (_seconds <= 0) timer.cancel();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiClient.postJson('/auth/reset-password', {
        'email': _sentEmail,
        'token': _code.text.trim(),
        'password': _password.text,
      }, authenticated: false);
      await ApiClient.clearToken();
      if (mounted) setState(() => _done = true);
      _timer?.cancel();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_sentEmail == null ? 'Quên mật khẩu' : 'Đặt lại mật khẩu'),
    ),
    body: SafeArea(
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
              _done ? Icons.check_circle_outline : Icons.lock_reset,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            if (_done) ...[
              const Text(
                'Đã đổi mật khẩu',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Đăng nhập lại bằng mật khẩu mới của bạn.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              AppButton(
                text: 'Về đăng nhập',
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (_) => false,
                ),
              ),
            ] else ...[
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
              ],
              if (_sentEmail == null) ...[
                const Text(
                  'Nhập email đã đăng ký để nhận mã xác nhận đặt lại mật khẩu.',
                ),
                const SizedBox(height: 24),
                AppInput(
                  key: const ValueKey('recovery-email'),
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  controller: _email,
                  validator: (value) =>
                      value != null &&
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(value.trim())
                      ? null
                      : 'Nhập email hợp lệ',
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: 'Gửi mã xác nhận',
                  isLoading: _busy,
                  onPressed: _busy ? null : _send,
                ),
              ] else ...[
                Text(
                  'Nếu email $_sentEmail đã đăng ký, mã xác nhận sẽ được gửi tới hộp thư. Kiểm tra cả thư rác.',
                ),
                const SizedBox(height: 24),
                AppInput(
                  key: const ValueKey('recovery-code'),
                  label: 'Mã xác nhận trong email',
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  controller: _code,
                  validator: (value) =>
                      RegExp(r'^\d{6,10}$').hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Nhập mã xác nhận từ email',
                ),
                const SizedBox(height: 16),
                AppInput(
                  label: 'Mật khẩu mới',
                  controller: _password,
                  isPassword: true,
                  validator: (value) =>
                      value != null && value.length >= 8 && value.length <= 128
                      ? null
                      : 'Mật khẩu từ 8 đến 128 ký tự',
                ),
                const SizedBox(height: 16),
                AppInput(
                  label: 'Nhập lại mật khẩu mới',
                  controller: _confirm,
                  isPassword: true,
                  validator: (value) => value == _password.text
                      ? null
                      : 'Mật khẩu nhập lại chưa khớp',
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: 'Đặt lại mật khẩu',
                  isLoading: _busy,
                  onPressed: _busy ? null : _reset,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy || _seconds > 0 ? null : _send,
                  child: Text(
                    _seconds > 0
                        ? 'Gửi lại mã sau $_seconds giây'
                        : 'Gửi lại mã xác nhận',
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          _timer?.cancel();
                          _code.clear();
                          _password.clear();
                          _confirm.clear();
                          setState(() {
                            _sentEmail = null;
                            _error = null;
                            _seconds = 0;
                          });
                        },
                  child: const Text('Thay đổi email'),
                ),
              ],
            ],
          ],
        ),
      ),
    ),
  );
}
