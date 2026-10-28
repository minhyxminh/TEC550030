import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tec550030/core/api/api_client.dart';
import 'package:tec550030/core/theme/app_theme.dart';
import 'package:tec550030/models/bmi_result.dart';
import 'package:tec550030/models/machine_guide.dart';
import 'package:tec550030/models/mascot_mood.dart';
import 'package:tec550030/models/point_transaction.dart';
import 'package:tec550030/screens/auth/login_screen.dart';
import 'package:tec550030/screens/guides/guide_video_screen.dart';
import 'package:tec550030/screens/guides/machine_guide_screen.dart';
import 'package:tec550030/screens/health/health_screen.dart';
import 'package:tec550030/screens/home/home_screen.dart';
import 'package:tec550030/services/video_service.dart';
import 'package:tec550030/widgets/brand.dart';
import 'package:tec550030/widgets/mascot.dart';

import 'api_fixtures.dart';

const _previewKey = ValueKey('preview');

Future<void> _show(
  WidgetTester tester,
  Widget page, {
  double height = 844,
}) async {
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _previewKey,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: page,
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('EXPORT_PREVIEWS')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_previewKey),
  );
  await tester.runAsync(() async {
    // Asset images decode outside the fake clock.
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element, onError: (_, _) {});
    }
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('.dart_tool/ui_previews').create(recursive: true);
    await File('.dart_tool/ui_previews/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

PointTransaction _checkin(DateTime at) => PointTransaction(
  id: '${at.millisecondsSinceEpoch}',
  points: 5,
  reason: 'Check-in tại phòng tập',
  type: 'EARN',
  createdAt: at,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const fontDir = String.fromEnvironment('FONT_DIR');
    if (fontDir.isEmpty) return;
    for (final weight in ['regular', 'bold', 'medium']) {
      final bytes = await File('$fontDir/roboto-$weight.ttf').readAsBytes();
      await (FontLoader(
        'Roboto',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    final icons = await File('$fontDir/materialicons-regular.otf')
        .readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(icons)))).load();

    // Brand fonts for previews (tests otherwise render the Ahem font).
    for (final (family, files) in [
      ('Baloo2', ['Baloo2-600', 'Baloo2-700', 'Baloo2-800']),
      (
        'BeVietnamPro',
        [
          'BeVietnamPro-Regular',
          'BeVietnamPro-Medium',
          'BeVietnamPro-SemiBold',
          'BeVietnamPro-Bold',
        ],
      ),
    ]) {
      final loader = FontLoader(family);
      for (final file in files) {
        final bytes = await File('assets/fonts/$file.ttf').readAsBytes();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
    }
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.clearToken();
    await ApiClient.saveSession({'access_token': 'valid-token'});
    ApiClient.httpClient = mockApi((request) async => fixtureResponse(request));
  });
  tearDown(() => ApiClient.httpClient.close());

  group('mascot mood', () {
    BmiResult bmi(double kg) => BmiResult(weightKg: kg, heightCm: 170, age: 25);

    test('follows BMI and weekly activity', () {
      expect(moodForHealth(null), MascotMood.thinking);
      expect(moodForHealth(bmi(50)), MascotMood.underweight);
      expect(moodForHealth(bmi(65)), MascotMood.happy);
      expect(moodForHealth(bmi(65), weeklyCheckins: 2), MascotMood.strong);
      expect(moodForHealth(bmi(80)), MascotMood.tired);
      expect(moodForHealth(bmi(100)), MascotMood.tired);
      expect(moodForHealth(bmi(80), weeklyCheckins: 3), MascotMood.celebrate);
      expect(moodForHealth(null, weeklyCheckins: 5), MascotMood.thinking);
    });

    test('weekly goal counts distinct Vietnam days in the last 7 days', () {
      final now = DateTime.utc(2026, 10, 23, 5);
      final history = [
        _checkin(DateTime.utc(2026, 10, 23, 1)),
        _checkin(DateTime.utc(2026, 10, 23, 2)), // same day
        _checkin(DateTime.utc(2026, 10, 20, 18)), // 21/10 in Vietnam
        _checkin(DateTime.utc(2026, 10, 10)), // too old
        PointTransaction(
          id: 'redeem',
          points: -20,
          reason: 'Đổi quà',
          type: 'REDEEM',
          createdAt: DateTime.utc(2026, 10, 22),
        ),
      ];
      expect(weeklyCheckinDays(history, now: now), 2);
    });

    test('every mood has encouraging copy', () {
      for (final mood in MascotMood.values) {
        expect(mood.info.label, isNotEmpty);
        expect(mood.info.message.length, greaterThan(10));
      }
    });
  });

  testWidgets('home replaces rewards with five machine guide videos', (
    tester,
  ) async {
    await _show(tester, const HomeScreen());
    expect(find.text('Khám phá phần quà'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Bài tập nổi bật'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Video ngắn giúp bạn tập đúng kỹ thuật'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('machine-guides')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('Squat tạ đơn'),
      400,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('machine-guides')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Squat tạ đơn'), findsOneWidget);
    expect(machineGuides, hasLength(5));
    expect(
      machineGuides.every((g) => g.videoUrl != null && g.thumbnailUrl != null),
      isTrue,
    );
    await _capture(tester, 'redesign-home-guides');
    await tester.tap(find.text('Squat tạ đơn'));
    await tester.pumpAndSettle();
    expect(find.text('Chuẩn bị'), findsOneWidget);
    expect(find.text('3 hiệp × 12 lần mỗi biến thể'), findsOneWidget);
    GuideVideoScreen.playerOverride = (g) => Text('player:${g.youtubeId}');
    addTearDown(() => GuideVideoScreen.playerOverride = null);
    await tester.ensureVisible(find.text('Xem video hướng dẫn'));
    await tester.tap(find.text('Xem video hướng dẫn'));
    await tester.pumpAndSettle();
    expect(find.text('player:xtRkNVQidDE'), findsOneWidget);
    // The YouTube app stays available as a fallback.
    Uri? opened;
    VideoService.launcher = (uri) async {
      opened = uri;
      return true;
    };
    await tester.tap(find.byTooltip('Mở trong YouTube'));
    await tester.pump();
    expect(opened.toString(), 'https://youtube.com/shorts/xtRkNVQidDE');
    expect(tester.takeException(), isNull);
  });

  testWidgets('guide list and detail render at 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: MachineGuideListScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Squat tạ đơn'), 200);
    expect(find.text('Squat tạ đơn'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(home: MachineGuideScreen(guide: machineGuides[3])),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('health mascot asks for data, then reacts to BMI', (
    tester,
  ) async {
    await _show(tester, const HealthScreen(), height: 1600);
    Mascot mascot() => tester.widget<Mascot>(
      find.descendant(
        of: find.byKey(const ValueKey('health-mascot')),
        matching: find.byType(Mascot),
      ),
    );
    expect(mascot().mood, MascotMood.thinking);
    expect(find.text('Nhập chỉ số ngay'), findsOneWidget);
    await _capture(tester, 'redesign-health-empty');

    for (final kg in [56.0, 85.0]) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'bmi_${profile['id']}',
        '{"weight_kg":$kg,"height_cm":170,"age":25,"measured_at":"2026-10-20T00:00:00Z"}',
      );
      await _show(tester, HealthScreen(key: ValueKey(kg)), height: 1600);
      expect(mascot().mood, kg < 60 ? MascotMood.happy : MascotMood.tired);
      await _capture(tester, 'redesign-health-${kg.round()}');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('mascot keeps a gentle idle loop and hops when tapped', (
    tester,
  ) async {
    Mascot.idleMotion = true;
    addTearDown(() => Mascot.idleMotion = false);
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: Mascot(mood: MascotMood.happy, width: 120)),
      ),
    );
    List<Matrix4> pose() => tester
        .widgetList<Transform>(
          find.descendant(
            of: find.byType(Mascot),
            matching: find.byType(Transform),
          ),
        )
        .map((t) => t.transform.clone())
        .toList();
    await tester.pump(const Duration(seconds: 2));
    final first = pose();
    await tester.pump(const Duration(milliseconds: 900));
    expect(pose(), isNot(equals(first)));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.tap(find.byType(Mascot));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    // Unmount so the endless loop stops before the test ends.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion keeps the mascot still', (tester) async {
    Mascot.idleMotion = true;
    addTearDown(() => Mascot.idleMotion = false);
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Center(child: Mascot(width: 120))),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('login renders the brand header', (tester) async {
    await _show(tester, const LoginScreen());
    expect(find.byType(GymFlowWordmark), findsOneWidget);
    expect(find.byType(Mascot), findsOneWidget);
    await _capture(tester, 'redesign-login');
    expect(tester.takeException(), isNull);
  });

  testWidgets('all mascot states render', (tester) async {
    await _show(
      tester,
      Scaffold(
        body: Center(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mood in MascotMood.values)
                Column(
                  children: [
                    Mascot(mood: mood, width: 112),
                    Text(mood.info.label, style: const TextStyle(fontSize: 11)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(Mascot), findsNWidgets(MascotMood.values.length));
    await _capture(tester, 'redesign-mascot-states');
    expect(tester.takeException(), isNull);
  });
}
