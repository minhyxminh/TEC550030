import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tec550030/core/api/api_client.dart';
import 'package:tec550030/core/theme/app_theme.dart';
import 'package:tec550030/screens/profile/profile_screen.dart';
import 'package:tec550030/screens/profile/catalogue_admin_screen.dart';
import 'package:tec550030/widgets/image_upload_field.dart';
import 'package:tec550030/widgets/app_button.dart';

import 'api_fixtures.dart';

void main() {
  final originalPicker = ImageUploadField.pickGallery;
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.clearToken();
    await ApiClient.saveSession({
      'access_token': 'valid-token',
      'refresh_token': 'refresh',
    });
    ImageUploadField.pickGallery = () async =>
        XFile.fromData(png, name: 'photo.png', mimeType: 'image/png');
  });
  tearDown(() {
    ImageUploadField.pickGallery = originalPicker;
    ApiClient.httpClient.close();
  });
  for (final kind in ['avatars', 'rewards', 'trainers']) {
    testWidgets(
      '$kind picker previews and uploads bytes before saving the profile or catalogue',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        bool uploaded = false;
        bool saved = false;
        const path =
            'avatars/a0000000-0000-4000-8000-000000000001/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.png';
        const url = 'https://example.com/uploaded.png';
        ApiClient.httpClient = mockApi((req) {
          if (req.url.path == '/media/$kind') {
            expect(req.headers['Authorization'], 'Bearer valid-token');
            expect(req.headers['Content-Type'], 'image/png');
            expect(req.bodyBytes, png);
            uploaded = true;
            return jsonResponse({'path': path, 'url': url});
          }
          if ((kind == 'avatars' &&
                  req.url.path == '/me' &&
                  req.method == 'PATCH') ||
              (req.url.path == '/admin/$kind' && req.method == 'POST')) {
            expect(uploaded, isTrue);
            final body = jsonDecode(req.body);
            expect(
              body[kind == 'avatars' ? 'avatar_path' : 'image_url'],
              kind == 'avatars' ? path : url,
            );
            saved = true;
            return jsonResponse({'id': 'saved'});
          }
          if (req.url.path.startsWith('/admin/') && req.method == 'GET') {
            return jsonResponse([]);
          }
          return fixtureResponse(req);
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: kind == 'avatars'
                ? const ProfileScreen()
                : const CatalogueAdminScreen(),
          ),
        );
        await tester.pumpAndSettle();
        if (kind == 'avatars') {
          await tester.tap(find.text('Chỉnh sửa hồ sơ'));
        } else {
          if (kind == 'trainers') {
            await tester.tap(find.text('Huấn luyện viên'));
            await tester.pumpAndSettle();
          }
          await tester.tap(
            find.text(
              kind == 'rewards' ? 'Thêm Phần quà' : 'Thêm Huấn luyện viên',
            ),
          );
        }
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chọn ảnh từ thiết bị'));
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsOneWidget);
        if (kind != 'avatars') {
          await tester.enterText(
            find.byType(TextFormField).at(0),
            'Uploaded item',
          );
          if (kind == 'rewards') {
            await tester.enterText(find.byType(TextFormField).at(2), '20');
          }
        }
        final save = kind == 'avatars'
            ? find.widgetWithText(AppButton, 'Lưu hồ sơ')
            : find.text('Lưu');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(saved, isTrue);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
