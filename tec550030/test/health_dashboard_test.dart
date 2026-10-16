import 'dart:convert';
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
import 'package:tec550030/models/health_guidance.dart';
import 'package:tec550030/models/user.dart';
import 'package:tec550030/screens/health/health_screen.dart';
import 'package:tec550030/services/health_service.dart';
import 'package:tec550030/widgets/gym_panel.dart';
import 'package:tec550030/widgets/measurement_ruler.dart';
import 'package:tec550030/widgets/weight_history_chart.dart';

import 'api_fixtures.dart';

const previewKey = ValueKey('health-preview');
Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('EXPORT_HEALTH_PREVIEWS')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(previewKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('.dart_tool/ui_previews').create(recursive: true);
    await File('.dart_tool/ui_previews/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const fontDir = String.fromEnvironment('FONT_DIR');
    if (fontDir.isEmpty) return;
    for (final family in ['Roboto', 'Ahem']) {
      final font = FontLoader(family);
      for (final weight in ['regular', 'medium', 'bold']) {
        font.addFont(
          Future.value(
            ByteData.sublistView(
              await File('$fontDir/roboto-$weight.ttf').readAsBytes(),
            ),
          ),
        );
      }
      await font.load();
    }
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(
            ByteData.sublistView(
              await File('$fontDir/materialicons-regular.otf').readAsBytes(),
            ),
          ),
        ))
        .load();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.clearToken();
    await ApiClient.saveSession({'access_token': 'valid-token'});
    ApiClient.httpClient = mockApi(fixtureResponse);
  });
  tearDown(() => ApiClient.httpClient.close());

  test(
    'history migrates the last BMI and replaces only the Vietnam calendar day',
    () async {
      final legacy = BmiResult(
        weightKg: 70,
        heightCm: 175,
        age: 25,
        measuredAt: DateTime.parse('2026-10-14T16:00:00Z'),
      );
      await (await SharedPreferences.getInstance()).setString(
        'bmi_a',
        jsonEncode(legacy.toJson()),
      );
      final service = HealthService();
      expect((await service.overview('a')).weights.single.weightKg, 70);
      await service.save(
        'a',
        BmiResult(
          weightKg: 69,
          heightCm: 175,
          age: 25,
          measuredAt: DateTime.parse('2026-10-14T18:00:00Z'),
        ),
      );
      await service.save(
        'a',
        BmiResult(
          weightKg: 68,
          heightCm: 175,
          age: 25,
          measuredAt: DateTime.parse('2026-10-15T10:00:00Z'),
        ),
      );
      final overview = await HealthService().overview('a');
      expect(overview.weights.map((e) => e.weightKg), [70, 68]);
      expect(overview.result!.weightKg, 68);
      expect((await service.overview('b')).weights, isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getString('bmi_a'),
        isNull,
      );
    },
  );
  test(
    'guidance changes by BMI category and gives five detailed suggestions',
    () {
      final plans = [17.0, 22.0, 27.0, 32.0, 37.0, 42.0]
          .map(
            (value) => HealthGuidance.forResult(
              BmiResult(weightKg: value * 4, heightCm: 200, age: 30),
            ),
          )
          .toList();
      expect(plans.take(4).map((p) => p.title).toSet().length, 4);
      expect(plans[3].title, isNot(plans[4].title));
      for (final plan in plans) {
        expect(plan.tips.length, 5);
        expect(plan.tips.every((tip) => tip.content.length > 100), isTrue);
      }
      expect(plans[0].tips[1].content, contains('300–500'));
      expect(plans[1].tips[0].content, contains('150'));
    },
  );
  testWidgets(
    'horizontal rulers choose tenths of kg and whole cm, and cancel does not save',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HealthScreen()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Tính BMI'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Tính BMI'));
      await tester.pumpAndSettle();
      final kg = find.byKey(const ValueKey('ruler-kg'));
      final previous = tester.widget<MeasurementRuler>(kg).value;
      await tester.drag(
        find.byKey(const ValueKey('ruler-scroll-kg')),
        const Offset(-120, 0),
      );
      await tester.pumpAndSettle();
      final current = tester.widget<MeasurementRuler>(kg).value;
      expect(current - previous, greaterThan(1));
      expect(current * 10, closeTo((current * 10).roundToDouble(), 0.001));
      await tester.ensureVisible(find.byKey(const ValueKey('ruler-cm')));
      await tester.drag(
        find.byKey(const ValueKey('ruler-scroll-cm')),
        const Offset(120, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MeasurementRuler>(find.byKey(const ValueKey('ruler-cm')))
            .value,
        lessThan(165),
      );
      await tester.ensureVisible(find.text('Hủy'));
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(await HealthService().latest(profile['id']! as String), isNull);
    },
  );
  testWidgets(
    'attendance shows the selected branch name instead of generic copy',
    (tester) async {
      ApiClient.httpClient = mockApi(
        (request) => request.url.path == '/gyms'
            ? jsonResponse([
                gymBranches.first,
                {...gymBranches.last, 'id': 'q6'},
              ])
            : fixtureResponse(request),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GymPanel(
                user: User.fromJson({...profile, 'home_gym_id': 'q6'}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('GymFlow Hậu Giang'), findsOneWidget);
      expect(
        find.text('Quét QR tại GymFlow Hậu Giang để bắt đầu buổi tập.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'dashboard uses real history and remains usable with large text at 320px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final user = profile['id']! as String;
      for (var i = 0; i < 3; i++) {
        await HealthService().save(
          user,
          BmiResult(
            weightKg: 70 - i.toDouble(),
            heightCm: 175,
            age: 25,
            measuredAt: DateTime.utc(2026, 10, 14 + i),
          ),
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const HealthScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WeightHistoryChart>(find.byType(WeightHistoryChart))
            .entries
            .length,
        3,
      );
      expect(find.text('68.0 kg'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Gợi ý sức khỏe'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('dashboard and measurement sheet previews', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (var i = 0; i < 5; i++) {
      await HealthService().save(
        profile['id']! as String,
        BmiResult(
          weightKg: 63 - i * 0.4,
          heightCm: 172,
          age: 25,
          measuredAt: DateTime.utc(2026, 10, 12 + i),
        ),
      );
    }
    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const HealthScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'health-dashboard');
    await tester.drag(find.byType(ListView).first, const Offset(0, -450));
    await tester.pumpAndSettle();
    await capture(tester, 'health-bmi');
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ghi cân nặng'));
    await tester.pumpAndSettle();
    await capture(tester, 'health-rulers');
    expect(tester.takeException(), isNull);
  });
  test('standalone weight logs do not create BMI and preserve known height and age', () async {
    final service = HealthService();
    await service.saveWeight('new-user', 75.2);
    final onlyWeight = await service.overview('new-user');
    expect(onlyWeight.result, isNull);
    expect(onlyWeight.weights.single.weightKg, 75.2);
    await service.save(
      'known-user',
      BmiResult(weightKg: 70, heightCm: 174, age: 31),
    );
    await service.saveWeight('known-user', 71.5);
    final updated = (await service.overview('known-user')).result!;
    expect(updated.weightKg, 71.5);
    expect(updated.heightCm, 174);
    expect(updated.age, 31);
  });

  testWidgets(
    'weight dashboard opens only kg and saves without height or age',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HealthScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ghi cân nặng'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ruler-kg')), findsOneWidget);
      expect(find.byKey(const ValueKey('ruler-cm')), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      final save = find.byKey(const ValueKey('save-health'));
      expect(save.hitTestable(), findsOneWidget);
      tester
          .widget<MeasurementRuler>(find.byKey(const ValueKey('ruler-kg')))
          .onChanged(81.2);
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();
      final saved = await HealthService().overview(profile['id']! as String);
      expect(saved.weights.single.weightKg, 81.2);
      expect(saved.result, isNull);
    },
  );

  testWidgets(
    'BMI save stays visible on a small screen, with large text and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const HealthScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Tính BMI'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Tính BMI'));
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('save-health'));
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.getRect(save).bottom, lessThanOrEqualTo(616));
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      tester.view.padding = const FakeViewPadding();
      await tester.pumpAndSettle();
      final before = tester.getRect(save);
      expect(before.bottom, lessThanOrEqualTo(400));
      await tester.drag(
        find.byKey(const ValueKey('health-sheet-content')),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(save).top, closeTo(before.top, 0.1));
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
