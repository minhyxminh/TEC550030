import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_client.dart';
import '../models/app_notification.dart';
import '../models/buddy_match.dart';
import '../models/user.dart';
import 'auth_service.dart';
import 'boss_service.dart';
import 'buddy_service.dart';
import 'chat_service.dart';
import 'workflow_service.dart';

/// Builds the in-app notification centre by polling the existing API while
/// the app is open and comparing with what was seen last time.
///
/// The server has no notifications table yet, so new messages, buddy
/// matches and order/reward/booking status changes are detected here and
/// kept on the device (per account, newest first).
class NotificationService with WidgetsBindingObserver {
  NotificationService._();
  static final instance = NotificationService._();

  /// Background polling; widget tests switch it off.
  static bool polling = true;
  static const _interval = Duration(seconds: 15);
  static const _maxItems = 60;

  final items = ValueNotifier<List<AppNotification>>(const []);

  /// Entries that arrived during the latest poll, for an in-app banner.
  final incoming = ValueNotifier<List<AppNotification>>(const []);

  int get unread => items.value.where((n) => !n.read).length;
  int get unreadMessages => items.value
      .where((n) => !n.read && n.kind == NotificationKind.message)
      .length;

  User? _user;
  Timer? _timer;
  bool _busy = false;
  int _listeners = 0;

  /// Conversation currently on screen; its messages are not announced.
  String? activeConversationId;

  /// Chats opened in this session, in case a poll overwrote [watch]'s save.
  final _watched = <String, String>{};

  String get _itemsKey => 'notifications_${_user?.id}';
  String get _stateKey => 'notification_state_${_user?.id}';

  /// Starts polling while at least one screen is listening.
  Future<void> attach() async {
    _listeners++;
    if (_listeners > 1) return;
    WidgetsBinding.instance.addObserver(this);
    items.value = const [];
    _user = null;
    _watched.clear();
    await _loadUser();
    if (!polling || _listeners == 0) return;
    unawaited(refresh());
    // Keeps ticking even if the first sign-in check failed (no network yet
    // right after start-up): every tick retries loading the account.
    _timer = Timer.periodic(_interval, (_) => refresh());
  }

  Future<bool> _loadUser() async {
    if (_user != null) return true;
    try {
      _user = await AuthService().getCurrentUser();
    } catch (error) {
      debugPrint('NotificationService: account not loaded yet ($error)');
      return false;
    }
    await _restore();
    return true;
  }

  void detach() {
    _listeners = (_listeners - 1).clamp(0, 1 << 30);
    if (_listeners > 0) return;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && polling) refresh();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_itemsKey);
    if (raw == null) return;
    try {
      items.value = [
        for (final row in jsonDecode(raw) as List)
          AppNotification.fromJson(Map<String, dynamic>.from(row as Map)),
      ];
    } catch (_) {
      items.value = const [];
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _itemsKey,
      jsonEncode([for (final n in items.value) n.toJson()]),
    );
  }

  /// Records something that just happened in this app (check-in, redemption).
  /// It is already read: the user saw the in-app toast for it.
  Future<void> record({
    required NotificationKind kind,
    required String title,
    String body = '',
  }) async {
    final now = DateTime.now();
    items.value = [
      AppNotification(
        id: 'local-${now.microsecondsSinceEpoch}',
        kind: kind,
        title: title,
        body: body,
        createdAt: now,
        read: true,
      ),
      ...items.value,
    ].take(_maxItems).toList();
    await _save();
  }

  Future<void> markRead(String id) async {
    items.value = [
      for (final n in items.value) n.id == id ? n.copyWith(read: true) : n,
    ];
    await _save();
  }

  Future<void> markConversationRead(String conversationId) async {
    if (!items.value.any(
      (n) => n.conversationId == conversationId && !n.read,
    )) {
      return;
    }
    items.value = [
      for (final n in items.value)
        n.conversationId == conversationId ? n.copyWith(read: true) : n,
    ];
    await _save();
  }

  Future<void> markAllRead() async {
    items.value = [for (final n in items.value) n.copyWith(read: true)];
    await _save();
  }

  Future<void> clear() async {
    items.value = const [];
    await _save();
  }

  /// Checks every source once. Safe to call at any time.
  Future<void> refresh() async {
    if (_busy || _listeners == 0) return;
    _busy = true;
    try {
      if (await ApiClient.getToken() == null) return;
      if (!await _loadUser()) return;
      final user = _user!;
      final prefs = await SharedPreferences.getInstance();
      final first = !prefs.containsKey(_stateKey);
      final state = first
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(
              jsonDecode(prefs.getString(_stateKey)!) as Map,
            );
      final found = <AppNotification>[];
      // Started one at a time, each inside its own try: a source that fails
      // early can never surface as an unhandled error.
      final checks = <Future<void> Function()>[
        if (user.role == 'ADMIN') ...[
          () => _adminInbox(state, found, first),
          () => _adminQueue(state, found, first),
          // Admins can have Gym Buddy chats and share the boss battle too.
          () => _memberMessages(user, state, found, admin: true),
          () => _boss(state, found),
        ] else ...[
          () => _memberMessages(user, state, found),
          () => _activity(state, found, first),
          () => _boss(state, found),
        ],
      ];
      for (final check in checks) {
        try {
          await check();
        } catch (error) {
          // One unavailable source must not block the others.
          debugPrint('NotificationService: check failed ($error)');
        }
      }
      await prefs.setString(_stateKey, jsonEncode(state));
      if (found.isEmpty) return;
      final known = items.value.map((n) => n.id).toSet();
      final fresh = found.where((n) => !known.contains(n.id)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (fresh.isEmpty) return;
      items.value = [...fresh, ...items.value].take(_maxItems).toList();
      incoming.value = fresh;
      await _save();
    } finally {
      _busy = false;
    }
  }

  // Support chat plus every buddy chat the member belongs to.
  Future<void> _memberMessages(
    User user,
    Map<String, dynamic> state,
    List<AppNotification> found, {
    bool admin = false,
  }) async {
    final chats = <String, String>{};
    // Each source on its own: a failing buddy lookup must not hide the
    // support chat, and the reverse. Admins answer support chats from the
    // inbox check instead, so those are left out here.
    if (!admin) {
      try {
        final support = await ChatService().open();
        chats[support['id'] as String] = 'GymFlow';
      } catch (error) {
        debugPrint('NotificationService: support chat unavailable ($error)');
      }
    }
    final inbox = admin
        ? (state['unread'] as Map?)?.keys.cast<String>().toSet() ?? <String>{}
        : const <String>{};
    final seenMatches = (state['matches'] as List?)?.cast<String>().toSet();
    var matches = const <BuddyMatch>[];
    try {
      matches = await const BuddyService().getMatches();
      state['matches'] = [for (final m in matches) m.id];
    } catch (error) {
      debugPrint('NotificationService: buddy matches unavailable ($error)');
    }
    // Chats seen before (e.g. a buddy group opened from the app) stay
    // watched even though the API cannot list them for members.
    final lastSeen = Map<String, dynamic>.from(state['seq'] as Map? ?? {});
    final names = Map<String, dynamic>.from(state['names'] as Map? ?? {});
    for (final MapEntry(:key, :value) in _watched.entries) {
      names.putIfAbsent(key, () => value);
    }
    final listed = {...chats.keys, for (final m in matches) ?m.conversationId};
    for (final id in {...lastSeen.keys, ...names.keys}) {
      if (inbox.contains(id)) continue; // a member's support chat
      chats.putIfAbsent(id, () => names[id] as String? ?? 'cuộc trò chuyện');
    }
    for (final m in matches) {
      if (m.conversationId != null) chats[m.conversationId!] = m.otherUserName;
      if (seenMatches != null && !seenMatches.contains(m.id)) {
        found.add(
          AppNotification(
            id: 'match-${m.id}',
            kind: NotificationKind.match,
            title: 'Gym Match mới!',
            body: 'Bạn và ${m.otherUserName} đã kết nối. Gửi lời chào nhé.',
            createdAt: m.createdAt?.toLocal() ?? DateTime.now(),
            conversationId: m.conversationId,
          ),
        );
      }
    }

    for (final MapEntry(key: id, value: name) in chats.entries) {
      names[id] = name;
      final List<Map<String, dynamic>> messages;
      try {
        messages = await ChatService().messages(id);
      } catch (error) {
        debugPrint('NotificationService: chat $id unavailable ($error)');
        continue;
      }
      if (messages.isEmpty) continue;
      final before = (lastSeen[id] as num?)?.toInt();
      // A newly watched group starts from its latest message.
      final baseline = before == null && !listed.contains(id);
      for (final m in messages) {
        if (baseline) break;
        final seq = (m['sequence'] as num).toInt();
        final mine = m['sender_id'] == user.id;
        // First time: only unread messages; afterwards anything newer.
        final isNew = before == null ? m['read_at'] == null : seq > before;
        if (mine || !isNew || id == activeConversationId) continue;
        found.add(
          AppNotification(
            id: 'msg-${m['id']}',
            kind: NotificationKind.message,
            title: 'Tin nhắn mới từ $name',
            body: m['content'] as String? ?? '',
            createdAt:
                DateTime.tryParse(m['created_at'] as String? ?? '')
                    ?.toLocal() ??
                DateTime.now(),
            conversationId: id,
          ),
        );
      }
      lastSeen[id] = messages
          .map((m) => (m['sequence'] as num).toInt())
          .reduce((a, b) => a > b ? a : b);
    }
    state['seq'] = lastSeen;
    state['names'] = names;
  }

  /// Watches a chat the API cannot list for members (a buddy group).
  Future<void> watch(String conversationId, String name) async {
    if (_user == null) return;
    _watched.putIfAbsent(conversationId, () => name);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey);
    final state = raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final seq = Map<String, dynamic>.from(state['seq'] as Map? ?? {});
    final names = Map<String, dynamic>.from(state['names'] as Map? ?? {});
    if (seq.containsKey(conversationId) || names.containsKey(conversationId)) {
      return;
    }
    // The next poll takes its latest message as the starting point.
    names[conversationId] = name;
    state['names'] = names;
    await prefs.setString(_stateKey, jsonEncode(state));
  }

  // Membership orders, rewards and PT bookings changing status.
  Future<void> _activity(
    Map<String, dynamic> state,
    List<AppNotification> found,
    bool first,
  ) async {
    final data = await WorkflowService().history();
    final previous = Map<String, dynamic>.from(state['status'] as Map? ?? {});
    final now = DateTime.now();
    final current = <String, String>{};
    void track(String key, String status, AppNotification? Function() build) {
      current[key] = status;
      if (first || previous[key] == status) return;
      final n = build();
      if (n != null) found.add(n);
    }

    for (final o in (data['orders'] as List? ?? []).cast<Map>()) {
      final status = o['payment_status'] == 'PAID' && o['status'] == 'PENDING'
          ? 'PAID'
          : o['status'] as String? ?? '';
      final plan = o['membership_name'] ?? 'gói tập';
      track('order-${o['id']}', status, () {
        return switch (status) {
          'APPROVED' => AppNotification(
            id: 'order-${o['id']}-approved',
            kind: NotificationKind.membership,
            title: 'Gói $plan đã kích hoạt',
            body: 'Gói tập của bạn đã sẵn sàng. Chúc bạn tập vui!',
            createdAt: now,
          ),
          'REJECTED' => AppNotification(
            id: 'order-${o['id']}-rejected',
            kind: NotificationKind.membership,
            title: 'Đơn gói $plan chưa được duyệt',
            body: 'Liên hệ GymFlow qua chat nếu bạn cần hỗ trợ.',
            createdAt: now,
          ),
          'PAID' => AppNotification(
            id: 'order-${o['id']}-paid',
            kind: NotificationKind.membership,
            title: 'Đã nhận thanh toán',
            body: 'GymFlow đã nhận tiền cho gói $plan.',
            createdAt: now,
          ),
          _ => null,
        };
      });
    }
    for (final r in (data['redemptions'] as List? ?? []).cast<Map>()) {
      final status = r['status'] as String? ?? '';
      track('reward-${r['id']}', status, () {
        if (status != 'FULFILLED') return null;
        return AppNotification(
          id: 'reward-${r['id']}-done',
          kind: NotificationKind.reward,
          title: 'Đã giao quà',
          body: '${r['reward_name'] ?? 'Phần quà'} đã được giao cho bạn.',
          createdAt: now,
        );
      });
    }
    final reminded =
        (state['reminded'] as List?)?.cast<String>().toSet() ?? <String>{};
    for (final b in (data['bookings'] as List? ?? []).cast<Map>()) {
      final status = b['status'] as String? ?? '';
      final trainer = b['trainer_name'] ?? 'PT';
      final slot = DateTime.tryParse(b['slot'] as String? ?? '')?.toLocal();
      track('booking-${b['id']}', status, () {
        if (status != 'CANCELLED') return null;
        return AppNotification(
          id: 'booking-${b['id']}-cancelled',
          kind: NotificationKind.booking,
          title: 'Lịch PT đã hủy',
          body: 'Buổi tập với $trainer đã được hủy.',
          createdAt: now,
        );
      });
      // One reminder within the hour before a confirmed session.
      if (status == 'CONFIRMED' &&
          slot != null &&
          slot.isAfter(now) &&
          slot.difference(now) <= const Duration(hours: 1) &&
          reminded.add(b['id'] as String)) {
        found.add(
          AppNotification(
            id: 'booking-${b['id']}-soon',
            kind: NotificationKind.booking,
            title: 'Sắp đến giờ tập với $trainer',
            body:
                'Buổi tập bắt đầu lúc ${slot.hour.toString().padLeft(2, '0')}:00. Chuẩn bị nhé!',
            createdAt: now,
          ),
        );
      }
    }
    state['status'] = current;
    state['reminded'] = reminded.toList();
  }

  // Đại chiến Boss: once a month when Hổ Flow is strong enough, and when
  // the boss falls.
  Future<void> _boss(
    Map<String, dynamic> state,
    List<AppNotification> found,
  ) async {
    final b = await const BossService().status();
    final month = '${b.month.year}-${b.month.month}';
    final seen = Map<String, dynamic>.from(state['boss'] as Map? ?? {});
    if (b.strongEnough && !b.defeated && seen['ready'] != month) {
      seen['ready'] = month;
      found.add(
        AppNotification(
          id: 'boss-ready-$month',
          kind: NotificationKind.boss,
          title: 'Hổ Flow đã đủ sức đánh Boss!',
          body:
              'Máu Hổ ${b.tigerHp} đã vượt Boss ${b.bossHp}. Vào đấu trường bấm Giao chiến ngay.',
          createdAt: DateTime.now(),
        ),
      );
    }
    if (b.defeated && seen['won'] != month) {
      seen['won'] = month;
      final next = b.month.month % 12 + 1;
      found.add(
        AppNotification(
          id: 'boss-won-$month',
          kind: NotificationKind.boss,
          title: 'Hạ Boss rồi! +${b.rewardPoints} GP vào ví',
          body: b.myHp > 0
              ? 'Cảm ơn bạn đã góp ${b.myHp} HP. Boss tháng $next sắp xuất hiện...'
              : 'Cả cộng đồng đã thắng. Boss tháng $next sắp xuất hiện...',
          createdAt: DateTime.now(),
        ),
      );
    }
    state['boss'] = seen;
  }

  // Admin: unread support messages.
  Future<void> _adminInbox(
    Map<String, dynamic> state,
    List<AppNotification> found,
    bool first,
  ) async {
    final previous = Map<String, dynamic>.from(state['unread'] as Map? ?? {});
    final current = <String, int>{};
    for (final c in await ChatService().inbox()) {
      final id = c['id'] as String;
      final unread = (c['unread'] as num?)?.toInt() ?? 0;
      current[id] = unread;
      final before = (previous[id] as num?)?.toInt() ?? 0;
      if (unread > before && id != activeConversationId) {
        found.add(
          AppNotification(
            id: 'inbox-$id-${c['updated_at']}',
            kind: NotificationKind.message,
            title: 'Tin nhắn mới từ ${c['name'] ?? 'hội viên'}',
            body: c['last_message'] as String? ?? '',
            createdAt:
                DateTime.tryParse(c['updated_at'] as String? ?? '')
                    ?.toLocal() ??
                DateTime.now(),
            conversationId: id,
          ),
        );
      }
    }
    state['unread'] = current;
  }

  // Admin: new membership orders and rewards waiting at the counter.
  Future<void> _adminQueue(
    Map<String, dynamic> state,
    List<AppNotification> found,
    bool first,
  ) async {
    final data = await WorkflowService().admin();
    final seen = (state['queue'] as List?)?.cast<String>().toSet();
    final ids = <String>[];
    for (final o in (data['orders'] as List? ?? []).cast<Map>()) {
      ids.add('o${o['id']}');
      if (seen == null || seen.contains('o${o['id']}')) continue;
      found.add(
        AppNotification(
          id: 'admin-order-${o['id']}',
          kind: NotificationKind.admin,
          title: 'Đơn gói tập mới',
          body: '${o['member_name']} đăng ký gói ${o['membership_name']}.',
          createdAt: DateTime.now(),
        ),
      );
    }
    for (final r in (data['redemptions'] as List? ?? []).cast<Map>()) {
      ids.add('r${r['id']}');
      if (seen == null || seen.contains('r${r['id']}')) continue;
      found.add(
        AppNotification(
          id: 'admin-reward-${r['id']}',
          kind: NotificationKind.admin,
          title: 'Quà chờ giao',
          body: '${r['member_name']} đã đổi ${r['reward_name']}.',
          createdAt: DateTime.now(),
        ),
      );
    }
    state['queue'] = ids;
  }
}
