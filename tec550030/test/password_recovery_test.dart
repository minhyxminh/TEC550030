import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tec550030/core/api/api_client.dart';
import 'package:tec550030/screens/auth/forgot_password_screen.dart';
import 'package:tec550030/widgets/app_button.dart';

import 'api_fixtures.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.clearToken();
  });
  tearDown(() => ApiClient.httpClient.close());
  testWidgets(
    'forgot password confirms by email code and validates matching visible passwords',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? resetBody;
      ApiClient.httpClient = mockApi((request) {
        expect(request.headers['Authorization'], isNull);
        if (request.url.path == '/auth/forgot-password') {
          expect(jsonDecode(request.body)['email'], 'member@example.com');
          return jsonResponse({'message': 'Check email'});
        }
        resetBody = jsonDecode(request.body);
        return jsonResponse({'message': 'Changed'});
      });
      await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
      await tester.enterText(find.byType(TextFormField), 'MEMBER@example.com');
      await tester.tap(find.widgetWithText(AppButton, 'Gửi mã xác nhận'));
      await tester.pumpAndSettle();
      expect(find.text('Mã xác nhận trong email'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), '123456');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'new-password123',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'different');
      await tester.tap(find.widgetWithText(AppButton, 'Đặt lại mật khẩu'));
      await tester.pumpAndSettle();
      expect(resetBody, isNull);
      expect(find.text('Mật khẩu nhập lại chưa khớp'), findsOneWidget);
      await tester.tap(find.byTooltip('Hiện mật khẩu mới'));
      await tester.pump();
      expect(find.byTooltip('Ẩn mật khẩu mới'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'new-password123',
      );
      await tester.tap(find.widgetWithText(AppButton, 'Đặt lại mật khẩu'));
      await tester.pumpAndSettle();
      expect(resetBody, {
        'email': 'member@example.com',
        'token': '123456',
        'password': 'new-password123',
      });
      expect(find.text('Đã đổi mật khẩu'), findsOneWidget);
      expect(await ApiClient.getToken(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
