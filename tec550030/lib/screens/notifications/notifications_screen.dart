import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/app_notification.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/decor.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/notification_bell.dart';
import '../chat/conversation_screen.dart';
import '../profile/activity_screen.dart';
import '../profile/admin_screen.dart';

/// Opens the screen a notification refers to and marks it read.
Future<void> openNotification(BuildContext context, AppNotification n) async {
  final service = NotificationService.instance;
  await service.markRead(n.id);
  if (!context.mounted) return;
  final Widget? target;
  switch (n.kind) {
    case NotificationKind.message || NotificationKind.match:
      final id = n.conversationId;
      if (id == null) return;
      final user = await AuthService().getCurrentUser();
      if (!context.mounted) return;
      final name = n.kind == NotificationKind.match
          ? n.body.replaceFirst('Bạn và ', '').split(' đã kết nối').first
          : n.title.replaceFirst('Tin nhắn mới từ ', '');
      target = ConversationScreen(
        conversationId: id,
        userId: user.id,
        title: name == 'GymFlow' ? 'Chat với GymFlow' : name,
      );
    case NotificationKind.admin:
      target = const AdminScreen();
    case NotificationKind.membership ||
        NotificationKind.reward ||
        NotificationKind.booking ||
        NotificationKind.checkin:
      target = const ActivityScreen();
  }
  await Navigator.push(context, MaterialPageRoute(builder: (_) => target!));
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService.instance;

  @override
  void initState() {
    super.initState();
    _service.refresh();
  }

  bool _isToday(DateTime t) {
    final now = DateTime.now();
    return t.year == now.year && t.month == now.month && t.day == now.day;
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tất cả thông báo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok == true) await _service.clear();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageBackdrop(
      topBlob: AppColors.peach,
      child: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<List<AppNotification>>(
          valueListenable: _service.items,
          builder: (context, items, _) {
            final today = items.where((n) => _isToday(n.createdAt)).toList();
            final earlier = items.where((n) => !_isToday(n.createdAt)).toList();
            Widget section(String title, List<AppNotification> list) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 10),
                  child: Text(title, style: AppTextStyles.heading2),
                ),
                for (final n in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: NotificationTile(
                      notification: n,
                      onTap: () => openNotification(context, n),
                    ),
                  ),
              ],
            );
            return RefreshIndicator(
              onRefresh: _service.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  PageHeader(
                    back: true,
                    title: 'Thông báo',
                    subtitle: _service.unread == 0
                        ? 'Bạn đã xem hết thông báo'
                        : '${_service.unread} thông báo chưa đọc',
                  ),
                  if (items.isNotEmpty)
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _service.unread == 0
                              ? null
                              : _service.markAllRead,
                          icon: const Icon(Icons.done_all_rounded, size: 18),
                          label: const Text('Đánh dấu đã đọc'),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _clear,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('Xóa tất cả'),
                        ),
                      ],
                    ),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: EmptyState(
                        message: 'Chưa có thông báo\nTin nhắn, ghép bạn tập, gói tập và quà sẽ hiện ở đây.',
                      ),
                    ),
                  if (today.isNotEmpty) section('Hôm nay', today),
                  if (earlier.isNotEmpty) section('Trước đó', earlier),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
