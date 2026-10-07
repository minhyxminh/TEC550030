import 'dart:convert';

import '../core/api/api_client.dart';
import '../models/user.dart';

class AuthService {
  Future<User?> login(String email, String password) async {
    try {
      final response = await ApiClient.post(
        '/auth/login',
        body: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['access_token'] != null) {
          await ApiClient.setToken(data['access_token']);
        }
        return User.fromJson(data['user'] ?? {});
      } else {
        throw Exception(jsonDecode(response.body)['message'] ?? 'Login failed');
      }
    } catch (e) {
      throw Exception('Failed to login: $e');
    }
  }

  Future<void> register(String name, String email, String password) async {
    try {
      final response = await ApiClient.post(
        '/auth/register',
        body: {'name': name, 'email': email, 'password': password},
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception(
          jsonDecode(response.body)['message'] ?? 'Registration failed',
        );
      }
    } catch (e) {
      throw Exception('Failed to register: $e');
    }
  }

  Future<User> getCurrentUser() async {
    try {
      final response = await ApiClient.get('/me');
      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to get user profile');
      }
    } catch (e) {
      throw Exception('Failed to fetch profile: $e');
    }
  }

  Future<void> logout() async {
    await ApiClient.clearToken();
  }

  Future<bool> isLoggedIn() async {
    final token = await ApiClient.getToken();
    return token != null;
  }
}
