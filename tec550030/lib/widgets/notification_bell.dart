import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';
import 'app_card.dart';

/// Icon and tint per notification kind.
(IconData, Color, Color) notificationStyle(NotificationKind kind) =>
    switch (kind) {
      NotificationKind.message => (
        Icons.chat_bubble_rounded,
        AppColors.purple,
        AppColors.lavender,
      ),
      NotificationKind.match => (
        Icons.favorite_rounded,
        const Color(0xFFFF5E8A),
        const Color(0xFFFFE3EC),
      ),
      NotificationKind.membership => (
        Icons.workspace_premium_rounded,
        AppColors.strongOrange,
        AppColors.peach,
      ),
      NotificationKind.reward => (
        Icons.redeem_rounded,
        AppColors.success,
        AppColors.mint,
      ),
      NotificationKind.booking => (
        Icons.event_available_rounded,
        AppColors.info,
        AppColors.infoSoft,
      ),
      NotificationKind.checkin => (
        Icons.qr_code_scanner_rounded,
        AppColors.primaryOrange,
        AppColors.peach,
      ),
      NotificationKind.admin => (
        Icons.admin_panel_settings_rounded,
        AppColors.ink,
        AppColors.field,
      ),
    };

/// Red count bubble over any widget.
class CountBadge extends StatelessWidget {
  final int count;
  final Widget child;
  const CountBadge({super.key, required this.count, required this.child});
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      if (count > 0)
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            constraints: const BoxConstraints(minWidth: 20),
            height: 20,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: AppTextStyles.overline.copyWith(
                color: Colors.white,
                fontSize: 10,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
    ],
  );
}

/// Bell button with the unread count; opens the notification centre.
class NotificationBell extends StatelessWidget {
  final VoidCallback onTap;
  const NotificationBell({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<List<AppNotification>>(
        valueListenable: NotificationService.instance.items,
        builder: (context, _, _) => Tooltip(
          message: 'Thông báo',
          child: CountBadge(
            count: NotificationService.instance.unread,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppShadows.soft,
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.ink,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// One notification row.
class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  static String timeAgo(DateTime time) {
    final d = DateTime.now().difference(time);
    if (d.inMinutes < 1) return 'Vừa xong';
    if (d.inMinutes < 60) return '${d.inMinutes} phút trước';
    if (d.inHours < 24) return '${d.inHours} giờ trước';
    if (d.inDays < 7) return '${d.inDays} ngày trước';
    return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final (icon, tint, background) = notificationStyle(n.kind);
    return AppCard(
      onTap: onTap,
      color: n.read ? Colors.white : const Color(0xFFFFF7F1),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon, color: tint, background: background, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title,
                  style: AppTextStyles.title.copyWith(
                    fontWeight: n.read ? FontWeight.w600 : FontWeight.w800,
                  ),
                ),
                if (n.body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    n.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(timeAgo(n.createdAt), style: AppTextStyles.caption),
              ],
            ),
          ),
          if (!n.read)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 6, left: 8),
              decoration: const BoxDecoration(
                color: AppColors.primaryOrange,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

/// Banner that slides in at the top for a few seconds.
void showNotificationBanner(
  BuildContext context,
  AppNotification notification, {
  required VoidCallback onTap,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  var removed = false;
  void remove() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => _Banner(
      notification: notification,
      onTap: () {
        remove();
        onTap();
      },
      onDone: remove,
    ),
  );
  overlay.insert(entry);
}

class _Banner extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onTap, onDone;
  const _Banner({
    required this.notification,
    required this.onTap,
    required this.onDone,
  });
  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final (icon, tint, background) = notificationStyle(n.kind);
    return AnimatedBuilder(
      animation: _life,
      builder: (context, child) {
        final v = _life.value;
        final shown = v < 0.08
            ? Curves.easeOutBack.transform(v / 0.08)
            : v > 0.92
            ? 1 - Curves.easeIn.transform((v - 0.92) / 0.08)
            : 1.0;
        return Positioned(
          left: 16,
          right: 16,
          top: MediaQuery.paddingOf(context).top + 10 - (1 - shown) * 60,
          child: Opacity(opacity: shown.clamp(0.0, 1.0), child: child),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: widget.onTap,
          onVerticalDragEnd: (_) => widget.onDone(),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.soft,
            ),
            child: Row(
              children: [
                IconTile(icon, color: tint, background: background),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        n.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.title.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      if (n.body.isNotEmpty)
                        Text(
                          n.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
