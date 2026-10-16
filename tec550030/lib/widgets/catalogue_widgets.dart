import 'package:material_ui/material_ui.dart';

import '../core/formatters.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/membership.dart';
import 'app_card.dart';

class AppImage extends StatelessWidget {
  final String url;
  final IconData icon;
  const AppImage({
    super.key,
    required this.url,
    this.icon = Icons.card_giftcard,
  });
  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppColors.primaryOrange.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Icon(icon, size: 40, color: AppColors.primaryOrange),
    );
    final uri = Uri.tryParse(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child:
          uri == null ||
              !['http', 'https'].contains(uri.scheme) ||
              uri.host.isEmpty
          ? placeholder
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, _, _) => placeholder,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : placeholder,
            ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  const StatusPill(
    this.text, {
    super.key,
    this.color = AppColors.primaryOrange,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Text(
      text,
      style: AppTextStyles.caption.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const SectionTitle(this.title, {super.key, this.subtitle, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.heading2),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: AppTextStyles.caption),
              ],
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class PointBalanceCard extends StatelessWidget {
  final int balance;
  final VoidCallback? onTap;
  const PointBalanceCard({super.key, required this.balance, this.onTap});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        colors: [AppColors.deepOrange, AppColors.primaryOrange],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.stars_rounded, color: AppColors.gymPointYellow),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'GymPoint của bạn',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          children: [
            Text(
              formatNumber(balance),
              style: AppTextStyles.display.copyWith(
                color: Colors.white,
                fontSize: 42,
              ),
            ),
            const Text(
              'GP',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Điểm tích lũy dành cho những phần quà bạn yêu thích.',
          style: TextStyle(color: Colors.white, fontSize: 13),
        ),
        if (onTap != null) ...[
          const SizedBox(height: 12),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
            onPressed: onTap,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Xem ví điểm'),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class MembershipCard extends StatelessWidget {
  final Membership membership;
  final VoidCallback? onTap;
  final String? status;
  const MembershipCard({
    super.key,
    required this.membership,
    this.onTap,
    this.status,
  });
  @override
  Widget build(BuildContext context) => AppCard(
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
              child: Text(membership.name, style: AppTextStyles.heading2),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: AppColors.secondaryText),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          formatPrice(membership.priceVnd),
          style: AppTextStyles.heading1.copyWith(color: AppColors.deepOrange),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill('${membership.durationDays} ngày'),
            StatusPill(
              '+${formatNumber(membership.pointsPerCheckin)} GP / ngày',
              color: AppColors.deepOrange,
            ),
            StatusPill(
              '+${formatNumber(membership.pointsOnActivation)} GP kích hoạt',
              color: AppColors.success,
            ),
            if (status != null) StatusPill(status!, color: AppColors.success),
          ],
        ),
        if (membership.description.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(membership.description, style: AppTextStyles.body),
        ],
      ],
    ),
  );
}

class ComingSoonCard extends StatelessWidget {
  final String title, message;
  final IconData icon;
  const ComingSoonCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.schedule,
  });
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primaryOrange),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: AppTextStyles.heading2)),
          ],
        ),
        const SizedBox(height: 12),
        const StatusPill('Sắp ra mắt'),
        const SizedBox(height: 12),
        Text(message, style: AppTextStyles.body),
      ],
    ),
  );
}
