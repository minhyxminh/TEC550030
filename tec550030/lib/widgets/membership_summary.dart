import 'package:material_ui/material_ui.dart';

import '../core/formatters.dart';
import '../core/theme/app_colors.dart';
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
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                color: AppColors.primaryOrange,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  user.activeMembershipId == null
                      ? 'Chưa có gói tập'
                      : membership?.name ?? 'Gói tập của bạn',
                  style: AppTextStyles.heading2,
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right),
            ],
          ),
          const SizedBox(height: 12),
          if (user.activeMembershipId == null)
            const Text(
              'Khám phá các gói tập và quyền lợi phù hợp với bạn.',
              style: AppTextStyles.body,
            )
          else ...[
            StatusPill(
              active ? 'Đang hoạt động' : 'Đã hết hạn',
              color: active ? AppColors.success : AppColors.error,
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
                '${formatNumber(membership.pointsPerCheckin)} GP cho mỗi QR check-in mới',
                style: AppTextStyles.caption,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
