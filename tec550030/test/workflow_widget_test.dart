import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tec550030/core/api/api_client.dart';
import 'package:tec550030/core/theme/app_theme.dart';
import 'package:tec550030/models/user.dart';
import 'package:tec550030/screens/profile/activity_screen.dart';
import 'package:tec550030/screens/profile/admin_screen.dart';
import 'package:tec550030/screens/profile/catalogue_admin_screen.dart';
import 'package:tec550030/screens/services/catalogue_details.dart';
import 'package:tec550030/screens/services/pt_booking_screen.dart';
import 'package:tec550030/widgets/app_button.dart';
import 'package:tec550030/widgets/gym_panel.dart';
import 'package:tec550030/widgets/workflow_button.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'api_fixtures.dart';

Future<void> page(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: child));
  await tester.pumpAndSettle();
}

Future<void> confirm(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.widgetWithText(AppButton, text));
  await tester.tap(find.widgetWithText(AppButton, text));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Xác nhận'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.clearToken();
    await ApiClient.saveSession({
      'access_token': 'valid-token',
      'refresh_token': 'refresh-token',
    });
    ApiClient.httpClient = mockApi((req) => fixtureResponse(req));
  });
  tearDown(() => ApiClient.httpClient.close());

  testWidgets(
    'mutation retries keep one idempotency key and expose network errors',
    (tester) async {
      final keys = <String>[];
      ApiClient.httpClient = mockApi((req) {
        keys.add(jsonDecode(req.body)['idempotency_key']);
        return keys.length == 1
            ? jsonResponse({'message': 'Tạm thời không thể xử lý.'}, 503)
            : jsonResponse({'id': 'created'});
      });
      await page(
        tester,
        const Scaffold(
          body: RequestButton(
            path: '/redemptions',
            body: {'reward_id': rewardId},
            text: 'Đổi quà',
            confirmation: 'Xác nhận đổi?',
            success: 'Đổi thành công',
          ),
        ),
      );
      await confirm(tester, 'Đổi quà');
      expect(find.text('Tạm thời không thể xử lý.'), findsOneWidget);
      await confirm(tester, 'Đổi quà');
      expect(keys.length, 2);
      expect(keys[0], keys[1]);
      expect(find.text('Đổi thành công'), findsWidgets);
    },
  );

  testWidgets('membership order sends catalogue ID, never price or user ID', (
    tester,
  ) async {
    Map<String, dynamic>? body;
    ApiClient.httpClient = mockApi((req) {
      if (req.url.path == '/membership-orders') body = jsonDecode(req.body);
      return fixtureResponse(req);
    });
    await page(tester, const MembershipDetailScreen(id: membershipId));
    await confirm(tester, 'Đăng ký gói tập');
    expect(body!['membership_id'], membershipId);
    expect(body!['idempotency_key'], isA<String>());
    expect(body!.containsKey('price_vnd_at_order'), isFalse);
    expect(body!.containsKey('user_id'), isFalse);
    expect(
      find.text('Đã gửi đơn. Vui lòng thanh toán tại quầy.'),
      findsWidgets,
    );
  });

  testWidgets(
    'PT shows unavailable slots and books only the selected UTC slot',
    (tester) async {
      final slot = DateTime.now()
          .toUtc()
          .add(const Duration(days: 1))
          .toIso8601String();
      Map<String, dynamic>? body;
      ApiClient.httpClient = mockApi((req) {
        if (req.url.path.endsWith('/slots')) {
          return jsonResponse([
            {'slot': slot, 'available': body == null},
            {
              'slot': DateTime.parse(slot)
                  .add(const Duration(hours: 1))
                  .toIso8601String(),
              'available': false,
            },
          ]);
        }
        if (req.url.path == '/pt-bookings') {
          body = jsonDecode(req.body);
          return jsonResponse({'id': 'booking'});
        }
        return fixtureResponse(req);
      });
      await page(
        tester,
        const PtBookingScreen(trainerId: trainerId, trainerName: 'PT Minh'),
      );
      expect(
        tester.widget<ChoiceChip>(find.byType(ChoiceChip).at(1)).onSelected,
        isNull,
      );
      await tester.tap(find.byType(ChoiceChip).first);
      await tester.pumpAndSettle();
      await confirm(tester, 'Đặt buổi tập');
      expect(body!['trainer_id'], trainerId);
      expect(body!['slot'], slot);
      expect(
        find.text('Đã đặt lịch. Xem trong Hoạt động của tôi.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(AppButton, 'Đặt buổi tập'), findsNothing);
    },
  );

  testWidgets(
    'QR manual check-in updates occupancy/session and check-out closes it',
    (tester) async {
      Map<String, dynamic>? session;
      String? sentToken;
      ApiClient.httpClient = mockApi((req) {
        if (req.url.path == '/gym/session') return jsonResponse(session);
        if (req.url.path == '/gym/gym-west/occupancy') {
          return jsonResponse({'count': session == null ? 0 : 1});
        }
        if (req.url.path == '/gym/gym-west/hourly') {
          return jsonResponse([
            {'hour': 6, 'count': session == null ? 0 : 1},
          ]);
        }
        if (req.url.path == '/gym/check-in') {
          sentToken = jsonDecode(req.body)['token'];
          session = {
            'id': 'session-1',
            'check_in_at': DateTime.now().toUtc().toIso8601String(),
          };
          return jsonResponse({
            'session': session,
            'points_earned': 10,
            'already_checked_in': false,
          });
        }
        if (req.url.path == '/gym/check-out') {
          expect(jsonDecode(req.body)['session_id'], 'session-1');
          session = null;
          return jsonResponse({'id': 'session-1'});
        }
        return fixtureResponse(req);
      });
      await page(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: GymPanel(
              user: User(
                id: 'member-id',
                name: 'Member',
                email: 'member@example.com',
                activeMembershipId: 'membership-id',
                homeGymId: 'gym-west',
                membershipActive: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('0 người đang tập'), findsOneWidget);
      await tester.tap(find.text('Nhập mã thay cho camera'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'raw-QR');
      await tester.tap(find.text('Check-in'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(sentToken, 'raw-QR');
      expect(find.text('1 người đang tập'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Check-out'));
      await tester.pumpAndSettle();
      expect(find.text('0 người đang tập'), findsOneWidget);
      await tester.pumpWidget(
        const SizedBox(),
      ); // Dispose occupancy polling timer.
    },
  );

  testWidgets(
    'activity history shows names/status and cancels a future booking',
    (tester) async {
      var cancelled = false;
      ApiClient.httpClient = mockApi((req) {
        if (req.url.path == '/activity') {
          return jsonResponse({
            'sessions': [],
            'redemptions': [],
            'orders': [],
            'bookings': [
              {
                'id': 'booking-1',
                'trainer_name': 'PT Minh',
                'slot': DateTime.now()
                    .add(const Duration(days: 1))
                    .toUtc()
                    .toIso8601String(),
                'status': cancelled ? 'CANCELLED' : 'CONFIRMED',
              },
            ],
          });
        }
        if (req.url.path == '/pt-bookings/booking-1/cancel') {
          cancelled = true;
          return jsonResponse({'id': 'booking-1', 'status': 'CANCELLED'});
        }
        return fixtureResponse(req);
      });
      await page(tester, const ActivityScreen());
      await tester.ensureVisible(find.text('Lịch PT'));
      await tester.tap(find.text('Lịch PT'));
      await tester.pumpAndSettle();
      expect(find.text('PT Minh'), findsOneWidget);
      await confirm(tester, 'Hủy lịch');
      expect(find.text('Đã hủy'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Hủy lịch'), findsNothing);
    },
  );

  testWidgets(
    'admin panel respects forbidden response and reopens the same automatic hourly QR',
    (tester) async {
      var forbidden = true;
      ApiClient.httpClient = mockApi((req) {
        if (req.url.path == '/admin/dashboard') {
          return forbidden
              ? jsonResponse({
                  'message': 'Chỉ quản trị viên được thực hiện thao tác này.',
                }, 403)
              : jsonResponse({
                  'orders': [],
                  'redemptions': [],
                  'qr_tokens': [],
                });
        }
        if (req.url.path == '/admin/qr-current') {
          return jsonResponse({
            'id': 'qr-1',
            'gym_id': '1',
            'token': 'AB12CD34EF',
            'expires_at': DateTime.now()
                .add(const Duration(minutes: 15))
                .toUtc()
                .toIso8601String(),
          });
        }
        return fixtureResponse(req);
      });
      await page(tester, const AdminScreen());
      expect(
        find.text('Chỉ quản trị viên được thực hiện thao tác này.'),
        findsOneWidget,
      );
      expect(find.text('Tạo QR mới'), findsNothing);
      forbidden = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('AB12CD34EF'), findsOneWidget);
      expect(find.text('Trang trước'), findsNothing);
      expect(find.text('Trang 1'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await page(tester, const AdminScreen());
      expect(find.text('AB12CD34EF'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'admin cancellation explains branch reset and closes open sessions',
    (tester) async {
      var cancelled = false;
      Map<String, dynamic>? cancellationBody;
      ApiClient.httpClient = mockApi((req) {
        if (req.url.path == '/admin/dashboard') {
          return jsonResponse({
            'orders': [],
            'redemptions': [],
            'qr_tokens': [],
          });
        }
        if (req.url.path == '/admin/members') {
          return jsonResponse(
            cancelled
                ? []
                : [
                    {
                      'user_id': 'member-1',
                      'name': 'Member One',
                      'membership_name': 'Basic',
                      'home_gym_id': 'gym-west',
                      'membership_expires_at': '2099-01-01T00:00:00Z',
                      'has_open_session': true,
                    },
                  ],
          );
        }
        if (req.url.path == '/admin/members/member-1/cancel-membership') {
          cancellationBody = jsonDecode(req.body);
          cancelled = true;
          return jsonResponse({
            'user_id': 'member-1',
            'has_open_session': true,
          });
        }
        if (req.url.path == '/admin/qr-current') {
          return jsonResponse({
            'id': 'qr-1',
            'gym_id': '1',
            'token': 'AB12CD34EF',
            'expires_at': DateTime.now()
                .add(const Duration(minutes: 15))
                .toUtc()
                .toIso8601String(),
          });
        }
        return fixtureResponse(req);
      });

      await page(tester, const AdminScreen());
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('Member One · Basic'), findsOneWidget);
      expect(
        find.textContaining('hủy gói sẽ kết thúc buổi tập này'),
        findsOneWidget,
      );
      final cancelButton = find.widgetWithText(AppButton, 'Hủy membership');
      tester.widget<AppButton>(cancelButton).onPressed!.call();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Lịch sử điểm và buổi tập vẫn được giữ.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(cancelled, isTrue);
      expect(cancellationBody!['reason'], 'Hủy theo quyết định Admin.');
      expect(
        find.text(
          'Đã hủy membership. Hội viên có thể chọn lại cơ sở và đăng ký gói mới.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'admin catalogue form submits validated fields and archives without deleting history',
    (tester) async {
      Map<String, dynamic>? added;
      var archived = false;
      ApiClient.httpClient = mockApi((req) {
        if (req.url.path == '/admin/rewards' && req.method == 'GET') {
          return jsonResponse([
            {...rewards.first, 'is_active': !archived},
            if (added != null) {...added!, 'id': 'added'},
          ]);
        }
        if (req.url.path == '/admin/rewards' && req.method == 'POST') {
          added = jsonDecode(req.body);
          return jsonResponse({'id': 'added', ...added!});
        }
        if (req.url.path == '/admin/rewards/$rewardId/archive') {
          archived = true;
          return jsonResponse({'id': rewardId, 'is_active': false});
        }
        return fixtureResponse(req);
      });
      await page(tester, const CatalogueAdminScreen());
      await confirm(tester, 'Ẩn khỏi danh mục');
      expect(archived, isTrue);
      expect(find.text('Đã ẩn'), findsOneWidget);
      // Let the archive success snackbar finish before opening a long form.
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.text('Thêm Phần quà'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Quà mới');
      await tester.enterText(find.byType(TextFormField).at(2), '30');
      await tester.enterText(find.byType(TextFormField).at(3), '5');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Lưu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(added!['points'], 30);
      expect(added!['stock'], 5);
      expect(find.text('Quà mới'), findsOneWidget);
    },
  );
}
