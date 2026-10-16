import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tec550030/core/api/api_client.dart';
import 'package:tec550030/core/theme/app_colors.dart';
import 'package:tec550030/models/bmi_result.dart';
import 'package:tec550030/models/occupancy.dart';
import 'package:tec550030/services/auth_service.dart';
import 'package:tec550030/services/biometric_service.dart';
import 'package:tec550030/services/health_service.dart';
import 'package:tec550030/screens/auth/session_gate.dart';
import 'package:tec550030/screens/health/health_screen.dart';
import 'package:tec550030/screens/chat/conversation_screen.dart';
import 'package:tec550030/screens/chat/chat_entry_screen.dart';
import 'package:tec550030/screens/main_layout/main_layout.dart';
import 'package:tec550030/widgets/hourly_occupancy_chart.dart';

import 'api_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.clearToken();
    ApiClient.sessionExpired.value = false;
    ApiClient.httpClient = mockApi(fixtureResponse);
    BiometricService.authenticateOverride = null;
  });
  tearDown(() {
    ApiClient.httpClient.close();
    BiometricService.authenticateOverride = null;
  });

  test('BMI validates inputs and classifies exact unrounded thresholds', () {
    BmiResult bmi(double value) =>
        BmiResult(weightKg: value * 4, heightCm: 200, age: 30);
    expect(bmi(18.49).categoryIndex, 0);
    expect(bmi(18.5).categoryIndex, 1);
    expect(bmi(24.99).categoryIndex, 1);
    expect(bmi(25).categoryIndex, 2);
    expect(bmi(30).categoryIndex, 3);
    expect(
      BmiResult(weightKg: 70, heightCm: 175, age: 25).bmi,
      closeTo(22.857, 0.001),
    );
    for (final value in [0.0, -1.0, double.nan, double.infinity, 351.0]) {
      expect(
        () => BmiResult(weightKg: value, heightCm: 175, age: 25),
        throwsFormatException,
      );
    }
    expect(
      () => BmiResult(weightKg: 70, heightCm: 0, age: 25),
      throwsFormatException,
    );
    expect(
      () => BmiResult(weightKg: 70, heightCm: 175, age: 19),
      throwsFormatException,
    );
  });
  test(
    'BMI persistence is isolated by account and tolerates corrupted data',
    () async {
      final service = HealthService();
      await service.save('a', BmiResult(weightKg: 70, heightCm: 175, age: 25));
      expect((await service.latest('a'))!.weightKg, 70);
      expect(await service.latest('b'), isNull);
      await (await SharedPreferences.getInstance()).setString(
        'health_a',
        '{bad',
      );
      expect(await service.latest('a'), isNull);
    },
  );
  test(
    'remember off stores no tokens or password, yet refresh works in memory',
    () async {
      await AuthService().login(
        'anh@example.com',
        'password123',
        remember: false,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), isNull);
      expect(prefs.getString('refresh_token'), isNull);
      expect(prefs.getString('remembered_email'), isNull);
      expect(prefs.getKeys().any((key) => key.contains('password')), isFalse);
      expect(await ApiClient.getToken(), 'valid-token');
      ApiClient.httpClient = mockApi((request) {
        if (request.url.path == '/auth/refresh') {
          expect(jsonDecode(request.body)['refresh_token'], 'valid-refresh');
          return jsonResponse({
            'access_token': 'renewed',
            'refresh_token': 'renewed-refresh',
          });
        }
        return request.headers['Authorization'] == 'Bearer renewed'
            ? jsonResponse({'balance': 80})
            : jsonResponse({'message': 'Expired'}, 401);
      });
      expect(await ApiClient.getJson('/points/balance'), {'balance': 80});
      expect(prefs.getString('refresh_token'), isNull);
      await AuthService().logout();
      expect(await ApiClient.getToken(), isNull);
    },
  );
  for (final accepted in [true, false]) {
    testWidgets(
      'saved biometric session accepted=$accepted before profile request',
      (tester) async {
        await ApiClient.saveSession({
          'access_token': 'valid-token',
          'refresh_token': 'valid-refresh',
        });
        await (await SharedPreferences.getInstance()).setBool(
          'biometric_enabled',
          true,
        );
        var requested = false;
        BiometricService.authenticateOverride = () async => accepted;
        ApiClient.httpClient = mockApi((request) {
          requested = true;
          return fixtureResponse(request);
        });
        await tester.pumpWidget(
          MaterialApp(
            home: const SessionGate(),
            routes: {
              '/login': (_) => const Scaffold(body: Text('Password fallback')),
              '/main_layout': (_) =>
                  const Scaffold(body: Text('Home unlocked')),
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(accepted ? 'Home unlocked' : 'Password fallback'),
          findsOneWidget,
        );
        expect(requested, accepted);
        if (!accepted) expect(await ApiClient.getToken(), isNull);
      },
    );
  }
  testWidgets('revoked refresh returns SessionGate to login', (tester) async {
    await ApiClient.saveSession({
      'access_token': 'old',
      'refresh_token': 'revoked',
    });
    ApiClient.httpClient = mockApi(
      (request) => jsonResponse({'message': 'Expired'}, 401),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: const SessionGate(),
        routes: {
          '/login': (_) => const Scaffold(body: Text('Password fallback')),
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Password fallback'), findsOneWidget);
  });
  testWidgets(
    'hour chart preserves every provided hour, zero bar and current highlight with horizontal scrolling',
    (tester) async {
      final hours = List.generate(
        17,
        (i) => HourlyOccupancy(hour: i + 6, count: i == 11 ? 0 : i),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: HourlyOccupancyChart(data: hours, currentHour: 17),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final h in hours) {
        expect(find.text('${h.hour}h'), findsOneWidget);
      }
      final chart = tester.widget<BarChart>(find.byType(BarChart));
      final current = chart.data.barGroups
          .singleWhere((g) => g.x == 17)
          .barRods
          .single;
      expect(current.toY, 0);
      expect(current.color, AppColors.primaryOrange);
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-700, 0),
      );
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, greaterThan(0));
      expect(find.text('22h').hitTestable(), findsOneWidget);
    },
  );
  testWidgets('BMI rulers validate age, calculate and persist the result', (
    tester,
  ) async {
    await ApiClient.saveSession({'access_token': 'valid-token'});
    await tester.pumpWidget(const MaterialApp(home: HealthScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Tính BMI'), 300);
    await tester.ensureVisible(find.text('Tính BMI'));
    await tester.tap(find.text('Tính BMI'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0');
    await tester.ensureVisible(find.byKey(const ValueKey('save-health')));
    await tester.tap(find.byKey(const ValueKey('save-health')));
    await tester.pumpAndSettle();
    expect(find.text('Nhập tuổi từ 20 đến 120'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '25');
    await tester.ensureVisible(find.byKey(const ValueKey('save-health')));
    await tester.tap(find.byKey(const ValueKey('save-health')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('22.0'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('22.0'), findsOneWidget);
    expect(find.text('Cân nặng khỏe mạnh'), findsOneWidget);
    expect(
      (await HealthService().latest(profile['id']! as String))!.weightKg,
      60,
    );
  });
  testWidgets(
    'navigation routes point balance to rewards and provides Health tab',
    (tester) async {
      await ApiClient.saveSession({'access_token': 'valid-token'});
      await tester.pumpWidget(const MaterialApp(home: MainLayout()));
      await tester.pumpAndSettle();
      final nav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(nav.items.map((e) => e.label), [
        'Trang chủ',
        'Sức khỏe',
        'Đổi thưởng',
        'Dịch vụ',
        'Tài khoản',
      ]);
      nav.onTap!(2);
      await tester.pumpAndSettle();
      expect(find.text('Lịch sử điểm'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
    },
  );
  testWidgets(
    'chat retries preserve request id and show one confirmed message',
    (tester) async {
      await ApiClient.saveSession({'access_token': 'valid-token'});
      final keys = <String>[];
      var sent = false;
      final message = {
        'id': 'm1',
        'sequence': 1,
        'sender_id': 'me',
        'content': 'Xin chào',
        'created_at': '2026-10-16T08:00:00Z',
        'read_at': null,
      };
      ApiClient.httpClient = mockApi((request) {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/messages')) {
          keys.add(jsonDecode(request.body)['client_id'] as String);
          if (keys.length == 1) {
            return jsonResponse({'message': 'Network retry'}, 503);
          }
          sent = true;
          return jsonResponse(message);
        }
        if (request.url.path.endsWith('/read')) {
          return jsonResponse({'ok': true});
        }
        return jsonResponse({
          'messages': sent ? [message] : [],
        });
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: ConversationScreen(
            conversationId: 'c1',
            userId: 'me',
            title: 'Support',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Xin chào');
      await tester.tap(find.byTooltip('Gửi'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Gửi'));
      await tester.pumpAndSettle();
      expect(keys.length, 2);
      expect(keys[0], keys[1]);
      expect(find.text('Xin chào'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Admin opens member inbox, reads messages and replies', (
    tester,
  ) async {
    await ApiClient.saveSession({'access_token': 'valid-token'});
    final messages = <Map<String, dynamic>>[
      {
        'id': 'm1',
        'sequence': 1,
        'sender_id': 'member',
        'content': 'Cần hỗ trợ gói tập',
        'created_at': '2026-10-16T08:00:00Z',
        'read_at': null,
      },
    ];
    var readThrough = 0;
    ApiClient.httpClient = mockApi((request) {
      if (request.url.path == '/me') {
        return jsonResponse({...profile, 'role': 'ADMIN'});
      }
      if (request.url.path == '/chat/inbox') {
        return jsonResponse({
          'conversations': [
            {
              'id': 'c1',
              'name': 'Hội viên Lan',
              'last_message': 'Cần hỗ trợ gói tập',
              'unread': 1,
              'updated_at': '2026-10-16T08:00:00Z',
            },
          ],
        });
      }
      if (request.url.path.endsWith('/read')) {
        readThrough = jsonDecode(request.body)['through'] as int;
        return jsonResponse({'ok': true});
      }
      if (request.method == 'POST') {
        final reply = {
          'id': 'm2',
          'sequence': 2,
          'sender_id': profile['id'],
          'content': jsonDecode(request.body)['content'],
          'created_at': '2026-10-16T08:01:00Z',
          'read_at': null,
        };
        messages.add(reply);
        return jsonResponse(reply);
      }
      return jsonResponse({'messages': messages});
    });
    await tester.pumpWidget(const MaterialApp(home: ChatEntryScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Hội viên Lan'), findsOneWidget);
    await tester.tap(find.text('Hội viên Lan'));
    await tester.pumpAndSettle();
    expect(readThrough, 1);
    expect(find.text('Cần hỗ trợ gói tập'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Mình sẽ hỗ trợ bạn.');
    await tester.tap(find.byTooltip('Gửi'));
    await tester.pumpAndSettle();
    expect(find.text('Mình sẽ hỗ trợ bạn.'), findsOneWidget);
    expect(readThrough, 2);
    await tester.pumpWidget(const SizedBox());
  });
}
