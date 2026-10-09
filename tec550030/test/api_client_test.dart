import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tec550030/core/api/api_client.dart';
import 'package:tec550030/services/auth_service.dart';
import 'package:tec550030/services/reward_service.dart';

import 'api_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.clearToken();
    ApiClient.sessionExpired.value = false;
  });
  tearDown(() => ApiClient.httpClient.close());

  test(
    'login stores real access/refresh tokens and normalizes email',
    () async {
      ApiClient.httpClient = mockApi((request) async {
        expect(jsonDecode(request.body)['email'], 'anh@example.com');
        expect(request.headers['Authorization'], isNull);
        return fixtureResponse(request);
      });
      final user = await AuthService().login(
        ' ANH@EXAMPLE.COM ',
        'password123',
      );
      expect(user.name, 'Lê Minh Anh');
      expect(await ApiClient.getToken(), 'valid-token');
      expect(
        (await SharedPreferences.getInstance()).getString('refresh_token'),
        'valid-refresh',
      );
    },
  );

  test(
    'concurrent expired requests refresh once and retry with renewed JWT',
    () async {
      await ApiClient.saveSession({
        'access_token': 'old',
        'refresh_token': 'old-refresh',
      });
      final started = Completer<void>();
      final renewal = Completer<void>();
      var refreshCalls = 0;
      ApiClient.httpClient = mockApi((request) async {
        if (request.url.path == '/auth/refresh') {
          refreshCalls++;
          expect(jsonDecode(request.body)['refresh_token'], 'old-refresh');
          if (!started.isCompleted) started.complete();
          await renewal.future;
          return jsonResponse({
            'access_token': 'new',
            'refresh_token': 'new-refresh',
          });
        }
        return request.headers['Authorization'] == 'Bearer new'
            ? jsonResponse({'balance': 80})
            : jsonResponse({'message': 'Expired'}, 401);
      });
      final results = Future.wait([
        ApiClient.getJson('/points/balance'),
        ApiClient.getJson('/points/balance'),
      ]);
      await started.future;
      renewal.complete();
      expect(await results, [
        {'balance': 80},
        {'balance': 80},
      ]);
      expect(refreshCalls, 1);
      expect(await ApiClient.getToken(), 'new');
    },
  );

  test(
    'rejected refresh clears session; transient server failure preserves it',
    () async {
      await ApiClient.saveSession({
        'access_token': 'old',
        'refresh_token': 'old-refresh',
      });
      var refreshStatus = 503;
      ApiClient.httpClient = mockApi(
        (request) async => jsonResponse({
          'message': 'Unavailable',
        }, request.url.path == '/auth/refresh' ? refreshStatus : 401),
      );
      await expectLater(ApiClient.getJson('/me'), throwsA(isA<ApiException>()));
      expect(await ApiClient.getToken(), 'old');
      expect(ApiClient.sessionExpired.value, false);
      refreshStatus = 401;
      await expectLater(ApiClient.getJson('/me'), throwsA(isA<ApiException>()));
      expect(await ApiClient.getToken(), isNull);
      expect(
        (await SharedPreferences.getInstance()).getString('refresh_token'),
        isNull,
      );
      expect(ApiClient.sessionExpired.value, true);
    },
  );

  test('logout during refresh cannot restore the old session', () async {
    await ApiClient.saveSession({
      'access_token': 'old',
      'refresh_token': 'old-refresh',
    });
    final started = Completer<void>();
    final renewal = Completer<void>();
    ApiClient.httpClient = mockApi((request) async {
      if (request.url.path == '/auth/refresh') {
        started.complete();
        await renewal.future;
        return jsonResponse({
          'access_token': 'new',
          'refresh_token': 'new-refresh',
        });
      }
      return jsonResponse({'message': 'Expired'}, 401);
    });
    final assertion = expectLater(
      ApiClient.getJson('/me'),
      throwsA(isA<ApiException>()),
    );
    await started.future;
    await AuthService().logout();
    renewal.complete();
    await assertion;
    expect(await ApiClient.getToken(), isNull);
  });

  test('an old request never retries as a newly signed-in account', () async {
    await ApiClient.saveSession({
      'access_token': 'account-a',
      'refresh_token': 'refresh-a',
    });
    final started = Completer<void>(), finish = Completer<void>();
    var requests = 0;
    ApiClient.httpClient = mockApi((request) async {
      requests++;
      started.complete();
      await finish.future;
      return jsonResponse({'message': 'Expired'}, 401);
    });
    final assertion = expectLater(
      ApiClient.getJson('/me'),
      throwsA(isA<ApiException>()),
    );
    await started.future;
    await ApiClient.saveSession({
      'access_token': 'account-b',
      'refresh_token': 'refresh-b',
    });
    finish.complete();
    await assertion;
    expect(requests, 1);
    expect(await ApiClient.getToken(), 'account-b');
  });

  test(
    'catalogues fetch past 100 records without sending a user JWT',
    () async {
      var pages = 0;
      ApiClient.httpClient = mockApi((request) async {
        expect(request.headers['Authorization'], isNull);
        pages++;
        final offset = int.parse(request.url.queryParameters['offset']!);
        return jsonResponse(
          offset == 0
              ? List.generate(100, (i) => {...rewards.first, 'id': '$i'})
              : [
                  {...rewards.first, 'id': '100'},
                ],
        );
      });
      expect((await RewardService().getRewards()).length, 101);
      expect(pages, 2);
    },
  );
}
