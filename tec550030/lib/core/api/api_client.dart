import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class ApiClient {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultApiBaseUrl,
  );
  static const _tokenKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static final sessionExpired = ValueNotifier(false);
  @visibleForTesting
  static http.Client httpClient = http.Client();
  static Future<void>? _refreshing;
  static int _sessionVersion = 0;
  static int _accountVersion = 0;

  static Future<String?> getToken() async =>
      (await SharedPreferences.getInstance()).getString(_tokenKey);

  static Future<void> saveSession(
    Map<String, dynamic> data, {
    bool renewing = false,
  }) async {
    final token = data['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw const ApiException('Không nhận được phiên đăng nhập.');
    }
    if (!renewing) {
      _accountVersion++;
      _refreshing = null;
    }
    _sessionVersion++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    final refresh = data['refresh_token'] as String?;
    if (refresh != null && refresh.isNotEmpty) {
      await prefs.setString(_refreshKey, refresh);
    } else {
      await prefs.remove(_refreshKey);
    }
    sessionExpired.value = false;
  }

  static Future<void> clearToken() async {
    _sessionVersion++;
    _accountVersion++;
    _refreshing = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshKey);
  }

  static Future<http.Response> _send(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    List<int>? bytes,
    String contentType = 'application/json',
    String? token,
  }) async {
    final request = http.Request(method, Uri.parse('$baseUrl$endpoint'));
    request.headers['Content-Type'] = contentType;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);
    if (bytes != null) request.bodyBytes = bytes;
    try {
      return await (() async => http.Response.fromStream(
        await httpClient.send(request),
      ))().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const ApiException('Kết nối quá lâu. Vui lòng thử lại.');
    } on http.ClientException {
      throw const ApiException('Không thể kết nối. Kiểm tra mạng và thử lại.');
    }
  }

  static dynamic _decode(http.Response response) {
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ApiException('Không thể đọc dữ liệu. Vui lòng thử lại.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        data is Map && data['message'] is String
            ? data['message'] as String
            : 'Không thể tải dữ liệu. Vui lòng thử lại.',
        response.statusCode,
      );
    }
    return data;
  }

  static Future<Map<String, dynamic>> patchJson(
    String endpoint,
    Map<String, dynamic> body,
  ) async => _decode(await patch(endpoint, body: body)) as Map<String, dynamic>;

  static Future<void> _expire(int version) async {
    if (version != _sessionVersion) return;
    await clearToken();
    sessionExpired.value = true;
  }

  static Future<void> _refreshSession() async {
    final version = _sessionVersion;
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString(_refreshKey);
    if (refresh == null) {
      await _expire(version);
      throw const ApiException(
        'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
        401,
      );
    }
    final response = await _send(
      'POST',
      '/auth/refresh',
      body: {'refresh_token': refresh},
    );
    if (response.statusCode == 401) {
      await _expire(version);
      throw const ApiException(
        'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
        401,
      );
    }
    final data = _decode(response) as Map<String, dynamic>;
    // Never restore an old session after logout or a new login.
    if (version != _sessionVersion) {
      throw const ApiException('Phiên đăng nhập đã thay đổi.', 401);
    }
    await saveSession(data, renewing: true);
  }

  static Future<http.Response> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    List<int>? bytes,
    String contentType = 'application/json',
    bool authenticated = true,
  }) async {
    final version = _sessionVersion;
    final accountVersion = _accountVersion;
    final token = authenticated ? await getToken() : null;
    if (authenticated && accountVersion != _accountVersion) {
      throw const ApiException('Phiên đăng nhập đã thay đổi.', 401);
    }
    if (authenticated && token == null) {
      await _expire(version);
      throw const ApiException('Vui lòng đăng nhập để tiếp tục.', 401);
    }
    var response = await _send(
      method,
      endpoint,
      body: body,
      bytes: bytes,
      contentType: contentType,
      token: token,
    );
    if (authenticated && accountVersion != _accountVersion) {
      throw const ApiException('Phiên đăng nhập đã thay đổi.', 401);
    }
    if (authenticated && response.statusCode == 401) {
      final currentToken = await getToken();
      if (currentToken == token) {
        final refreshing = _refreshing ??= _refreshSession();
        try {
          await refreshing;
        } finally {
          if (identical(_refreshing, refreshing)) _refreshing = null;
        }
      } else if (currentToken == null) {
        throw const ApiException('Vui lòng đăng nhập để tiếp tục.', 401);
      }
      final retryVersion = _sessionVersion;
      if (accountVersion != _accountVersion) {
        throw const ApiException('Phiên đăng nhập đã thay đổi.', 401);
      }
      response = await _send(
        method,
        endpoint,
        body: body,
        bytes: bytes,
        contentType: contentType,
        token: await getToken(),
      );
      if (response.statusCode == 401) await _expire(retryVersion);
    }
    return response;
  }

  static Future<http.Response> get(
    String endpoint, {
    bool authenticated = true,
  }) => _request('GET', endpoint, authenticated: authenticated);
  static Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) => _request('POST', endpoint, body: body, authenticated: authenticated);
  static Future<http.Response> patch(
    String endpoint, {
    Map<String, dynamic>? body,
  }) => _request('PATCH', endpoint, body: body);
  static Future<dynamic> getJson(
    String endpoint, {
    bool authenticated = true,
  }) async => _decode(await get(endpoint, authenticated: authenticated));
  static Future<Map<String, dynamic>> postJson(
    String endpoint,
    Map<String, dynamic> body, {
    bool authenticated = true,
  }) async =>
      _decode(await post(endpoint, body: body, authenticated: authenticated))
          as Map<String, dynamic>;

  static Future<List<dynamic>> catalogue(String endpoint) async {
    final all = <dynamic>[];
    for (var offset = 0; ; offset += 100) {
      final page = await getJson(
        '$endpoint?limit=100&offset=$offset',
        authenticated: false,
      ) as List<dynamic>;
      all.addAll(page);
      if (page.length < 100) return all;
    }
  }

  static Future<Map<String, dynamic>> uploadImage(
    String kind,
    List<int> bytes,
    String mime,
  ) async => _decode(
    await _request('POST', '/media/$kind', bytes: bytes, contentType: mime),
  ) as Map<String, dynamic>;
}
