import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tec550030/core/api/api_client.dart';
import 'package:tec550030/core/theme/app_theme.dart';
import 'package:tec550030/main.dart';
import 'package:tec550030/screens/gympoint/gympoint_screen.dart';
import 'package:tec550030/screens/home/home_screen.dart';
import 'package:tec550030/screens/profile/profile_screen.dart';
import 'package:tec550030/screens/rewards/rewards_screen.dart';
import 'package:tec550030/screens/services/services_screen.dart';
import 'package:tec550030/widgets/app_button.dart';
import 'package:tec550030/services/location_service.dart';

import 'api_fixtures.dart';

const _previewKey = ValueKey('preview');
Future<void> showPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(390, 844);
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

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('EXPORT_PREVIEWS')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_previewKey),
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
    if (fontDir.isNotEmpty) {
      for (final weight in ['regular', 'bold', 'medium']) {
        final bytes = await File('$fontDir/roboto-$weight.ttf').readAsBytes();
        await (FontLoader(
          'Roboto',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        await (FontLoader(
          'Ahem',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
      final icons = await File('$fontDir/materialicons-regular.otf')
          .readAsBytes();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(icons)))).load();
    }
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.clearToken();
    await ApiClient.saveSession({
      'access_token': 'valid-token',
      'refresh_token': 'valid-refresh',
    });
    ApiClient.httpClient = mockApi((request) async => fixtureResponse(request));
  });
  tearDown(() => ApiClient.httpClient.close());

  testWidgets(
    'saved session restores Home with live user, balance and membership',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const RepaintBoundary(key: _previewKey, child: MyApp()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lê Minh Anh'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
      expect(find.text('Basic'), findsOneWidget);
      expect(find.text('Quét QR check-in'), findsOneWidget);
      expect(find.text('47'), findsNothing);
      expect(tester.takeException(), isNull);
      await capture(tester, 'home');
    },
  );

  testWidgets('login failure stays on form; success loads real Home', (
    tester,
  ) async {
    await ApiClient.clearToken();
    var fail = true;
    ApiClient.httpClient = mockApi(
      (request) async => request.url.path == '/auth/login' && fail
          ? jsonResponse({'message': 'Email/mật khẩu không hợp lệ.'}, 401)
          : fixtureResponse(request),
    );
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'anh@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.ensureVisible(find.widgetWithText(AppButton, 'Đăng nhập'));
    await tester.tap(find.widgetWithText(AppButton, 'Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Email/mật khẩu không hợp lệ.'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    fail = false;
    await tester.ensureVisible(find.widgetWithText(AppButton, 'Đăng nhập'));
    await tester.tap(find.widgetWithText(AppButton, 'Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Lê Minh Anh'), findsOneWidget);
    expect(await ApiClient.getToken(), 'valid-token');
  });

  testWidgets('Home sends members without an active package to Join', (
    tester,
  ) async {
    int? selectedTab;
    ApiClient.httpClient = mockApi((request) async {
      if (request.url.path == '/me') {
        return jsonResponse({
          ...profile,
          'active_membership_id': null,
          'membership_expires_at': null,
          'membership_active': false,
        });
      }
      return fixtureResponse(request);
    });
    await showPage(
      tester,
      HomeScreen(onSelectTab: (index) => selectedTab = index),
    );
    expect(find.text('Tham gia'), findsOneWidget);
    final joinButton = find.widgetWithText(AppButton, 'Tham gia');
    tester.widget<AppButton>(joinButton).onPressed!.call();
    expect(selectedTab, 3);
  });

  testWidgets('Home sends active members without a selected gym to Join', (
    tester,
  ) async {
    ApiClient.httpClient = mockApi((request) async {
      if (request.url.path == '/me') {
        return jsonResponse({...profile, 'home_gym_id': null});
      }
      return fixtureResponse(request);
    });
    await showPage(tester, const HomeScreen());
    expect(find.text('Tham gia'), findsOneWidget);
    expect(find.text('Quét QR check-in'), findsNothing);
    expect(find.text('Chọn cơ sở để xem occupancy.'), findsOneWidget);
  });

  testWidgets('Home only enables check-in after explicit branch selection', (
    tester,
  ) async {
    String? selectedGym;
    ApiClient.httpClient = mockApi((request) async {
      if (request.url.path == '/me') {
        return jsonResponse({...profile, 'home_gym_id': selectedGym});
      }
      if (request.url.path == '/me/home-gym') {
        selectedGym = jsonDecode(request.body)['gym_id'] as String;
        return jsonResponse({...profile, 'home_gym_id': selectedGym});
      }
      return fixtureResponse(request);
    });
    await showPage(
      tester,
      HomeScreen(
        locationService: LocationService(
          locationProvider: () async => const LocationResult(denied: true),
        ),
      ),
    );
    expect(find.text('Tham gia'), findsOneWidget);
    tester
        .widget<AppButton>(find.widgetWithText(AppButton, 'Tham gia'))
        .onPressed!
        .call();
    await tester.pumpAndSettle();
    expect(find.text('Chọn cơ sở tập'), findsOneWidget);
    await tester.tap(find.text('GymFlow Hậu Giang'));
    await tester.pumpAndSettle();
    expect(selectedGym, 'q5');
    expect(find.text('Quét QR check-in'), findsOneWidget);
  });

  testWidgets(
    'registration validates eight characters and explains email confirmation',
    (tester) async {
      await ApiClient.clearToken();
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Đăng ký ngay'));
      await tester.tap(find.text('Đăng ký ngay'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Lê Minh Anh');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'anh@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'short');
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Đăng ký'));
      await tester.tap(find.widgetWithText(AppButton, 'Đăng ký'));
      await tester.pumpAndSettle();
      expect(find.text('Mật khẩu phải từ 8 đến 128 ký tự'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.enterText(find.byType(TextFormField).at(3), 'different123');
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Đăng ký'));
      await tester.tap(find.widgetWithText(AppButton, 'Đăng ký'));
      await tester.pumpAndSettle();
      expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);
      expect(find.text('Xác nhận email'), findsNothing);
      await tester.enterText(find.byType(TextFormField).at(3), 'password123');
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Đăng ký'));
      await tester.tap(find.widgetWithText(AppButton, 'Đăng ký'));
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận email'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
      await tester.tap(find.text('Về đăng nhập'));
      await tester.pumpAndSettle();
      expect(find.text('Đăng nhập để tiếp tục'), findsOneWidget);
      expect(await ApiClient.getToken(), isNull);
    },
  );

  testWidgets('expired session returns to login with a clear message', (
    tester,
  ) async {
    ApiClient.httpClient = mockApi(
      (request) async =>
          ['/me', '/points/balance', '/auth/refresh'].contains(request.url.path)
          ? jsonResponse({'message': 'Expired'}, 401)
          : fixtureResponse(request),
    );
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập để tiếp tục'), findsOneWidget);
    expect(await ApiClient.getToken(), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rewards uses all API records, handles blank images and loads fresh detail',
    (tester) async {
      await showPage(tester, const RewardsScreen());
      expect(find.text('Nước khoáng'), findsOneWidget);
      expect(find.text('Thanh protein'), findsOneWidget);
      expect(find.text('Hết quà'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
      await capture(tester, 'rewards');
      await tester.tap(find.text('Nước khoáng'));
      await tester.pumpAndSettle();
      expect(find.text('Mô tả mới nhất từ API chi tiết.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.widgetWithText(AppButton, 'Đổi quà'),
        250,
      );
      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Đổi quà'),
      );
      expect(button.onPressed, isNotNull);
      await tester.tap(find.widgetWithText(AppButton, 'Đổi quà'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(
        find.text('Đã đổi quà. Xem mã nhận trong Hoạt động của tôi.'),
        findsWidgets,
      );
    },
  );

  testWidgets('load failure offers retry and never displays fake rewards', (
    tester,
  ) async {
    var fail = true;
    ApiClient.httpClient = mockApi(
      (request) async => fail
          ? jsonResponse({'message': 'Tạm thời không thể tải quà.'}, 503)
          : fixtureResponse(request),
    );
    await showPage(tester, const RewardsScreen());
    expect(find.text('Tạm thời không thể tải quà.'), findsOneWidget);
    expect(find.text('Nước khoáng'), findsNothing);
    fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Nước khoáng'), findsOneWidget);
  });

  testWidgets('services renders package price/rules and trainer list/details', (
    tester,
  ) async {
    await showPage(tester, const ServicesScreen());
    expect(find.text('300.000 ₫'), findsOneWidget);
    expect(find.text('30 ngày'), findsOneWidget);
    expect(find.text('+5 GP / ngày'), findsOneWidget);
    expect(find.text('+100 GP kích hoạt'), findsOneWidget);
    await capture(tester, 'memberships');
    await tester.tap(find.text('Basic'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết gói tập'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Huấn luyện viên'));
    await tester.pumpAndSettle();
    expect(find.text('PT Minh'), findsOneWidget);
    expect(find.text('3 năm kinh nghiệm'), findsOneWidget);
    await capture(tester, 'trainers');
    await tester.tap(find.text('PT Minh'));
    await tester.pumpAndSettle();
    expect(find.text('Đồng hành trong các buổi tập sức mạnh.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'wallet renders signed transactions and honest empty balance/history',
    (tester) async {
      await showPage(tester, const GymPointScreen());
      expect(find.text('+100 GP'), findsOneWidget);
      expect(find.text('-20 GP'), findsOneWidget);
      await capture(tester, 'wallet');
      ApiClient.httpClient = mockApi(
        (request) async => jsonResponse(
          request.url.path == '/points/balance' ? {'balance': 0} : [],
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await showPage(tester, const GymPointScreen());
      expect(find.text('0'), findsOneWidget);
      expect(find.textContaining('Chưa có giao dịch điểm.'), findsOneWidget);
      expect(find.text('1.250'), findsNothing);
    },
  );

  testWidgets('wallet can load more than the first twenty transactions', (
    tester,
  ) async {
    ApiClient.httpClient = mockApi((request) async {
      if (request.url.path == '/points/balance') {
        return jsonResponse({'balance': 200});
      }
      final offset = int.parse(request.url.queryParameters['offset']!);
      return jsonResponse(
        offset == 0
            ? List.generate(
                20,
                (i) => {...history.first, 'id': '$i', 'reason': 'Giao dịch $i'},
              )
            : [
                {...history.first, 'id': '20', 'reason': 'Giao dịch 20'},
              ],
      );
    });
    await showPage(tester, const GymPointScreen());
    await tester.scrollUntilVisible(find.text('Xem thêm giao dịch'), 500);
    await tester.ensureVisible(
      find.widgetWithText(AppButton, 'Xem thêm giao dịch'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem thêm giao dịch'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Giao dịch 20'), 300);
    expect(find.text('Giao dịch 20'), findsOneWidget);
    expect(find.text('Xem thêm giao dịch'), findsNothing);
  });

  testWidgets(
    'profile renders real email, membership expiry and account creation',
    (tester) async {
      await showPage(tester, const ProfileScreen());
      expect(find.text('anh@example.com'), findsOneWidget);
      expect(find.text('Thành viên từ 08/10/2026'), findsOneWidget);
      expect(find.text('Basic'), findsOneWidget);
      expect(find.text('Hạn sử dụng: 08/11/2099'), findsOneWidget);
      await capture(tester, 'profile');
      if (const bool.fromEnvironment('EXPORT_PREVIEWS')) {
        await tester.scrollUntilVisible(find.text('Đăng xuất'), 250);
        await capture(tester, 'profile_links');
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('catalogue remains usable at 320px and enlarged text', (
    tester,
  ) async {
    await showPage(tester, const RewardsScreen());
    tester.view.physicalSize = const Size(320, 740);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: const RewardsScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nước khoáng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
