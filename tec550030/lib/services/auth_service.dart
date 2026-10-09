import '../core/api/api_client.dart';
import '../models/user.dart';

class RegistrationResult {
  final bool requiresEmailConfirmation;
  final String message;
  const RegistrationResult(this.requiresEmailConfirmation, this.message);
}

class AuthService {
  Future<User> login(String email, String password) async {
    final data = await ApiClient.postJson('/auth/login', {
      'email': email.trim().toLowerCase(),
      'password': password,
    }, authenticated: false);
    await ApiClient.saveSession(data);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<RegistrationResult> register(
    String name,
    String email,
    String password,
  ) async {
    final data = await ApiClient.postJson('/auth/register', {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
    }, authenticated: false);
    final confirmation =
        data['requires_email_confirmation'] == true ||
        data['access_token'] == null;
    if (!confirmation) await ApiClient.saveSession(data);
    return RegistrationResult(
      confirmation,
      data['message'] as String? ?? 'Đăng ký thành công.',
    );
  }

  Future<User> getCurrentUser() async =>
      User.fromJson(await ApiClient.getJson('/me') as Map<String, dynamic>);
  Future<void> logout() => ApiClient.clearToken();
  Future<bool> isLoggedIn() async => await ApiClient.getToken() != null;
}
