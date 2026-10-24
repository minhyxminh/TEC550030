import 'package:material_ui/material_ui.dart';

import '../core/formatters.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../services/account_service.dart';
import 'app_card.dart';
import 'catalogue_widgets.dart';

class MembershipSummary extends StatelessWidget {
  final AccountOverview account;
  final VoidCallback? onTap;
  const MembershipSummary({super.key, required this.account, this.onTap});
  @override
  Widget build(BuildContext context) {
    final user = account.user;
    final matches = account.memberships.where(
      (m) => m.id == user.activeMembershipId,
    );
    final membership = matches.isEmpty ? null : matches.first;
    final active = user.hasActiveMembership;
    final none = user.activeMembershipId == null;
    final header = Row(
      children: [
        IconTile(
          Icons.fitness_center_rounded,
          background: none ? Colors.white : AppColors.peach,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                none
                    ? 'Chưa có gói tập'
                    : membership?.name ?? 'Gói tập của bạn',
                style: AppTextStyles.heading2,
              ),
              if (none)
                const Text(
                  'Khám phá các gói tập và quyền lợi phù hợp với bạn.',
                  style: AppTextStyles.caption,
                ),
            ],
          ),
        ),
        if (onTap != null)
          const Icon(Icons.chevron_right_rounded, color: AppColors.ink),
      ],
    );
    if (none) {
      return CustomPaint(
        foregroundPainter: _DashedBorder(
          color: AppColors.primaryOrange.withValues(alpha: 0.55),
        ),
        child: AppCard(onTap: onTap, color: AppColors.peach, child: header),
      );
    }
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 12),
          StatusPill(
            active ? 'Đang hoạt động' : 'Đã hết hạn',
            color: active ? AppColors.success : AppColors.error,
            background: active ? AppColors.mint : null,
          ),
          if (user.membershipExpiresAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Hạn sử dụng: ${formatDate(user.membershipExpiresAt!)}',
              style: AppTextStyles.body,
            ),
          ],
          if (membership != null && active) ...[
            const SizedBox(height: 8),
            Text(
              '${formatNumber(membership.pointsPerCheckin)} GP mỗi ngày check-in · '
              '${formatNumber(membership.pointsOnActivation)} GP khi kích hoạt',
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  final Color color;
  const _DashedBorder({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(AppRadius.lg),
        ).deflate(0.75),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
