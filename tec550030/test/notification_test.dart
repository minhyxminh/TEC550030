import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tec550030/core/api/api_client.dart';
import 'package:tec550030/core/theme/app_theme.dart';
import 'package:tec550030/models/app_notification.dart';
import 'package:tec550030/screens/notifications/notifications_screen.dart';
import 'package:tec550030/services/notification_service.dart';
import 'package:tec550030/widgets/notification_bell.dart';

import 'api_fixtures.dart';

const _support = 'c0000000-0000-4000-8000-000000000001';
const _buddyChat = 'c0000000-0000-4000-8000-000000000002';
const _me = 'a0000000-0000-4000-8000-000000000001';
const _lan = 'a0000000-0000-4000-8000-000000000002';

Map<String, dynamic> _message(
  int seq,
  String sender,
  String text, {
  bool read = false,
}) => {
  'id': 'm$seq',
  'sequence': seq,
  'conversation_id': _support,
  'sender_id': sender,
  'content': text,
  'created_at': '2026-10-28T08:0$seq:00Z',
  'read_at': read ? '2026-10-28T08:30:00Z' : null,
};

void main() {
  final service = NotificationService.instance;
  late List<Map<String, dynamic>> supportMessages;
  late List<Map<String, dynamic>> buddyMessages;
  late List<Map<String, dynamic>> matches;
  late List<Map<String, dynamic>> orders;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.saveSession({'access_token': 'valid-token'});
    supportMessages = [_message(1, _me, 'Chào GymFlow')];
    buddyMessages = [];
    matches = [];
    orders = [
      {
        'id': 'o1',
        'status': 'PENDING',
        'payment_status': 'UNPAID',
        'membership_name': 'Basic',
      },
    ];
    ApiClient.httpClient = mockApi((r) async {
      switch (r.url.path) {
        case '/chat/open':
          return jsonResponse({'id': _support});
        case '/buddy/matches':
          return jsonResponse({'matches': matches});
        case '/chat/$_support/messages':
          return jsonResponse({'messages': supportMessages});
        case '/chat/$_buddyChat/messages':
          return jsonResponse({'messages': buddyMessages});
        case '/activity':
          return jsonResponse({
            'sessions': [],
            'redemptions': [],
            'orders': orders,
            'bookings': [],
          });
      }
      return fixtureResponse(r);
    });
    await service.attach();
  });

  tearDown(() {
    service.detach();
    ApiClient.httpClient.close();
  });

  test('announces new messages, matches and activated plans once', () async {
    await service.refresh();
    expect(service.items.value, isEmpty);

    supportMessages = [
      ...supportMessages,
      _message(2, 'admin', 'Gói của bạn đã sẵn sàng'),
    ];
    matches = [
      {
        'id': 'match-1',
        'other_user_id': _lan,
        'other_user_name': 'Lan',
        'conversation_id': _buddyChat,
        'created_at': '2026-10-28T08:00:00Z',
      },
    ];
    orders = [
      {...orders.first, 'status': 'APPROVED', 'payment_status': 'PAID'},
    ];
    await service.refresh();

    final kinds = service.items.value.map((n) => n.kind).toSet();
    expect(kinds, {
      NotificationKind.message,
      NotificationKind.match,
      NotificationKind.membership,
    });
    expect(
      service.items.value
          .firstWhere((n) => n.kind == NotificationKind.message)
          .body,
      'Gói của bạn đã sẵn sàng',
    );
    expect(service.unread, 3);
    expect(service.unreadMessages, 1);

    // Nothing new: nothing announced twice.
    await service.refresh();
    expect(service.items.value, hasLength(3));

    await service.markConversationRead(_support);
    expect(service.unreadMessages, 0);
    await service.markAllRead();
    expect(service.unread, 0);
  });

  test('own messages and the open chat are not announced', () async {
    await service.refresh();
    service.activeConversationId = _support;
    supportMessages = [...supportMessages, _message(2, 'admin', 'Xin chào')];
    await service.refresh();
    supportMessages = [...supportMessages, _message(3, _me, 'Cảm ơn')];
    service.activeConversationId = null;
    await service.refresh();
    expect(service.items.value, isEmpty);
  });

  testWidgets('bell shows the unread count and the centre lists items', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await service.refresh();
      supportMessages = [...supportMessages, _message(2, 'admin', 'Hello')];
      await service.refresh();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(child: NotificationBell(onTap: () {})),
        ),
      ),
    );
    expect(find.text('1'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const NotificationsScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Tin nhắn mới từ GymFlow'), findsOneWidget);
    expect(find.text('1 thông báo chưa đọc'), findsOneWidget);
    await tester.tap(find.text('Đánh dấu đã đọc'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn đã xem hết thông báo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
