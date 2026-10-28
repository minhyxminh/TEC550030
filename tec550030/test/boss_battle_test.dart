import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tec550030/core/api/api_client.dart';
import 'package:tec550030/core/theme/app_theme.dart';
import 'package:tec550030/screens/boss/boss_battle_screen.dart';
import 'package:tec550030/services/boss_service.dart';

import 'api_fixtures.dart';

Map<String, dynamic> _battle({
  int tiger = 520,
  bool open = true,
  bool defeated = false,
  bool claimed = false,
  String? result,
}) => {
  'month': '2026-10-01',
  'boss_name': 'Quái Vật Lười Biếng',
  'boss_hp': 500,
  'tiger_hp': tiger,
  'my_hp': 4,
  'reward_points': 20,
  'days_left': 4,
  'fight_open': open,
  'defeated': defeated,
  'claimed': claimed,
  'top_branches': [
    {'gym_id': 'q1', 'name': 'Quận 1', 'hp': 210},
    {'gym_id': 'bt', 'name': 'Bình Thạnh', 'hp': 160},
  ],
  'result': ?result,
};

void main() {
  late List<String> calls;
  late bool deployed;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.saveSession({'access_token': 'valid-token'});
    calls = [];
    deployed = true;
    ApiClient.httpClient = mockApi((r) async {
      calls.add('${r.method} ${r.url.path}');
      if (r.url.path.startsWith('/boss') && !deployed) {
        return jsonResponse({
          'code': 'NOT_FOUND',
          'message': 'Endpoint chưa được triển khai.',
        }, 404);
      }
      switch (r.url.path) {
        case '/boss':
          return jsonResponse(_battle());
        case '/boss/fight':
          return jsonResponse(
            _battle(defeated: true, open: false, claimed: true, result: 'WIN'),
          );
        case '/activity':
          return jsonResponse({
            'sessions': [
              {
                'id': 's1',
                'check_in_at': DateTime.now().toUtc().toIso8601String(),
              },
            ],
            'redemptions': [],
            'orders': [],
            'bookings': [],
          });
      }
      return fixtureResponse(r);
    });
  });

  tearDown(() => ApiClient.httpClient.close());

  test('reads the community battle from the server', () async {
    final battle = await const BossService().status();
    expect(battle.tigerHp, 520);
    expect(battle.strongEnough, isTrue);
    expect(battle.topBranches.first.name, 'Quận 1');
  });

  test('says clearly when the server has not enabled the battle yet', () async {
    deployed = false;
    await expectLater(
      const BossService().status(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          BossService.notDeployed,
        ),
      ),
    );
  });

  testWidgets(
    'arena fights, shows the win and the reward already in the wallet',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const BossBattleScreen()),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(find.text('Đại chiến Boss'), findsOneWidget);
      expect(find.text('Hổ Flow đã đủ sức! Giao chiến thôi!'), findsOneWidget);
      expect(find.text('Chiến binh'), findsWidgets);

      await tester.tap(find.text('GIAO CHIẾN!'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      // Still mode: the cutscene shows the dust cloud for a second.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Bỏ qua'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Hạ Boss rồi! 🎉'), findsOneWidget);
      expect(calls, contains('POST /boss/fight'));

      // The reward is already in the wallet: no claim step.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('+20 GP'), findsWidgets);
      expect(find.text('đã vào ví GymPoint của bạn'), findsOneWidget);
      expect(calls.where((c) => c.contains('claim')), isEmpty);
      await tester.tap(find.text('Tuyệt vời!'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Hạ Boss rồi! 🎉'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
