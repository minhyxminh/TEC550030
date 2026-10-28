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
  var supportDown = false;
  Map<String, dynamic>? boss;
  var admin = false;
  late List<Map<String, dynamic>> inbox;
  var offline = false;

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
    supportDown = false;
    offline = false;
    boss = null;
    admin = false;
    inbox = [];
    ApiClient.httpClient = mockApi((r) async {
      if (offline) return jsonResponse({'code': 'ERROR', 'message': 'x'}, 503);
      switch (r.url.path) {
        case '/chat/open':
          if (supportDown) {
            return jsonResponse({'code': 'ERROR', 'message': 'x'}, 500);
          }
          return jsonResponse({'id': _support});
        case '/me' when admin:
          return jsonResponse({...profile, 'role': 'ADMIN'});
        case '/chat/inbox':
          return jsonResponse({'conversations': inbox});
        case '/admin/dashboard':
          return jsonResponse({'orders': [], 'redemptions': []});
        case '/boss':
          if (boss == null) {
            return jsonResponse({'code': 'NOT_FOUND', 'message': 'x'}, 404);
          }
          return jsonResponse(boss);
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

  test('a failing support chat does not hide buddy messages', () async {
    matches = [
      {
        'id': 'match-1',
        'other_user_id': _lan,
        'other_user_name': 'Lan',
        'conversation_id': _buddyChat,
        'created_at': '2026-10-28T08:00:00Z',
      },
    ];
    await service.refresh();
    supportDown = true;
    buddyMessages = [
      {..._message(1, _lan, 'Tập chân không?'), 'conversation_id': _buddyChat},
    ];
    await service.refresh();
    expect(
      service.items.value.map((n) => n.title),
      contains('Tin nhắn mới từ Lan'),
    );
  });

  test('retries loading the account after a failed start', () async {
    service.detach();
    offline = true;
    await service.attach();
    offline = false;
    supportMessages = [...supportMessages, _message(2, 'admin', 'Xin chào')];
    await service.refresh();
    expect(service.items.value.map((n) => n.body), contains('Xin chào'));
  });

  test(
    'announces the boss once when Hổ Flow is strong enough and when it falls',
    () async {
      Map<String, dynamic> battle({bool defeated = false}) => {
        'month': '2026-10-01',
        'boss_hp': 5000,
        'tiger_hp': 5012,
        'my_hp': 6,
        'reward_points': 20,
        'days_left': 3,
        'fight_open': !defeated,
        'defeated': defeated,
        'claimed': false,
        'top_branches': [],
      };
      boss = battle();
      await service.refresh();
      await service.refresh();
      expect(service.items.value.map((n) => n.title), [
        'Hổ Flow đã đủ sức đánh Boss!',
      ]);
      expect(
        service.items.value.single.body,
        'Máu Hổ 5012 đã vượt Boss 5000. Vào đấu trường bấm Giao chiến ngay.',
      );

      // A message still arrives alongside the boss news.
      supportMessages = [...supportMessages, _message(2, 'admin', 'Chào bạn')];
      boss = battle(defeated: true);
      await service.refresh();
      final titles = service.items.value.map((n) => n.title).toList();
      expect(titles, contains('Hạ Boss rồi! +20 GP vào ví'));
      expect(titles, contains('Tin nhắn mới từ GymFlow'));
      expect(
        service.items.value
            .firstWhere((n) => n.title.startsWith('Hạ Boss'))
            .body,
        'Cảm ơn bạn đã góp 6 HP. Boss tháng 11 sắp xuất hiện...',
      );
      await service.refresh();
      expect(service.items.value, hasLength(3));
    },
  );

  test(
    'admins get support, Gym Buddy and boss notifications once each',
    () async {
      service.detach();
      admin = true;
      matches = [
        {
          'id': 'match-1',
          'other_user_id': _lan,
          'other_user_name': 'Lan',
          'conversation_id': _buddyChat,
          'created_at': '2026-10-28T08:00:00Z',
        },
      ];
      inbox = [
        {
          'id': _support,
          'name': 'Hội viên An',
          'unread': 0,
          'last_message': '',
          'updated_at': '2026-10-28T08:00:00Z',
        },
      ];
      await service.attach();
      // The admin once opened this member's support chat.
      await service.watch(_support, 'Hội viên An');
      await service.refresh();
      expect(service.items.value, isEmpty);

      inbox = [
        {
          ...inbox.first,
          'unread': 1,
          'last_message': 'Cho mình hỏi gói VIP',
          'updated_at': '2026-10-28T09:00:00Z',
        },
      ];
      supportMessages = [
        ...supportMessages,
        _message(2, _lan, 'Cho mình hỏi gói VIP'),
      ];
      buddyMessages = [
        {
          ..._message(1, _lan, 'Chiều nay tập không?'),
          'conversation_id': _buddyChat,
        },
      ];
      boss = {
        'month': '2026-10-01',
        'boss_hp': 20,
        'tiger_hp': 21,
        'my_hp': 0,
        'reward_points': 20,
        'days_left': 3,
        'fight_open': true,
        'defeated': false,
        'claimed': false,
        'top_branches': [],
      };
      await service.refresh();
      final titles = service.items.value.map((n) => n.title).toList();
      expect(titles, hasLength(3));
      expect(titles, contains('Tin nhắn mới từ Hội viên An'));
      expect(titles, contains('Tin nhắn mới từ Lan'));
      expect(titles, contains('Hổ Flow đã đủ sức đánh Boss!'));
    },
  );

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
