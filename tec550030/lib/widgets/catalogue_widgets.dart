import 'package:material_ui/material_ui.dart';

import '../core/formatters.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../models/catalogue_media.dart';
import '../models/membership.dart';
import 'ambient.dart';
import 'app_card.dart';

/// Rotating soft tints for image placeholders and avatars.
const tilePalette = [
  (AppColors.infoSoft, AppColors.info),
  (AppColors.peach, AppColors.deepOrange),
  (AppColors.lavender, AppColors.purple),
  (AppColors.mint, AppColors.success),
];

class AppImage extends StatelessWidget {
  final String url;
  final IconData icon;
  final int tint;
  const AppImage({
    super.key,
    required this.url,
    this.icon = Icons.card_giftcard_rounded,
    this.tint = 1,
  });
  @override
  Widget build(BuildContext context) {
    final (background, foreground) = tilePalette[tint % tilePalette.length];
    final placeholder = Container(
      color: background,
      alignment: Alignment.center,
      child: Icon(icon, size: 40, color: foreground),
    );
    final uri = Uri.tryParse(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: isAssetImage(url)
          ? Image.asset(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, _, _) => placeholder,
            )
          : uri == null ||
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
  final Color? background;
  final IconData? icon;
  const StatusPill(
    this.text, {
    super.key,
    this.color = AppColors.deepOrange,
    this.background,
    this.icon,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: background ?? color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.heading2.copyWith(fontSize: 21)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
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

/// Ink balance card with a breathing glow and drifting bubbles.
class PointBalanceCard extends StatelessWidget {
  final int balance;
  final VoidCallback? onTap;
  final VoidCallback? onHistory;
  const PointBalanceCard({
    super.key,
    required this.balance,
    this.onTap,
    this.onHistory,
  });
  @override
  Widget build(BuildContext context) => HighlightCard(
    color: AppColors.ink,
    glow: AppColors.purple,
    seed: 4,
    bubbleIntensity: 0.45,
    padding: const EdgeInsets.all(22),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: -70,
          top: -70,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.inkSoft, width: 26),
            ),
          ),
        ),
        if (onTap == null)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.gymPointYellow,
                shape: BoxShape.circle,
              ),
              child: Text(
                'GP',
                style: AppTextStyles.heading2.copyWith(fontSize: 17),
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GymPoint của bạn',
                    style: AppTextStyles.title.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 8,
                    children: [
                      Text(
                        formatNumber(balance),
                        style: AppTextStyles.display.copyWith(
                          color: Colors.white,
                          fontSize: 48,
                          height: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'GP',
                          style: AppTextStyles.heading2.copyWith(
                            color: AppColors.gymPointYellow,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Điểm tích lũy dành cho những phần quà bạn yêu thích.',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  if (onHistory != null) ...[
                    const SizedBox(height: 14),
                    _PillButton(
                      label: 'Lịch sử điểm',
                      icon: Icons.receipt_long_rounded,
                      onTap: onHistory!,
                      leadingIcon: true,
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 12),
              Flexible(
                child: _PillButton(
                  label: 'Xem ví điểm',
                  icon: Icons.arrow_forward_rounded,
                  onTap: onTap!,
                  color: AppColors.gymPointYellow,
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

class _PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final bool leadingIcon;
  const _PillButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
    this.leadingIcon = false,
  });
  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 17, color: AppColors.ink);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingIcon) ...[iconWidget, const SizedBox(width: 6)],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title.copyWith(fontSize: 13.5),
                ),
              ),
              if (!leadingIcon) ...[const SizedBox(width: 6), iconWidget],
            ],
          ),
        ),
      ),
    );
  }
}

enum MembershipStyle { light, orange, ink }

class MembershipCard extends StatelessWidget {
  final Membership membership;
  final VoidCallback? onTap;
  final String? status;
  final MembershipStyle style;
  const MembershipCard({
    super.key,
    required this.membership,
    this.onTap,
    this.status,
    this.style = MembershipStyle.light,
  });

  /// Plans alternate white, orange and ink so each one reads separately.
  static MembershipStyle styleAt(int index) =>
      MembershipStyle.values[index % MembershipStyle.values.length];

  @override
  Widget build(BuildContext context) {
    final light = style == MembershipStyle.light;
    final ink = style == MembershipStyle.ink;
    final textColor = ink ? Colors.white : AppColors.ink;
    final iconTile = switch (style) {
      MembershipStyle.light => const IconTile(
        Icons.fitness_center_rounded,
        background: AppColors.peach,
        color: AppColors.primaryOrange,
      ),
      MembershipStyle.orange => const IconTile(
        Icons.local_fire_department_rounded,
        background: Colors.white,
        color: AppColors.strongOrange,
      ),
      MembershipStyle.ink => const IconTile(
        Icons.workspace_premium_rounded,
        background: AppColors.purple,
        color: Colors.white,
      ),
    };
    Widget pill(String text, int tone) {
      final (bg, fg) = switch (style) {
        MembershipStyle.light => [
          (AppColors.field, AppColors.ink),
          (AppColors.peach, AppColors.deepOrange),
          (AppColors.mint, AppColors.success),
        ][tone],
        MembershipStyle.orange => [
          (Colors.white, AppColors.ink),
          (Colors.white, AppColors.ink),
          (AppColors.ink, Colors.white),
        ][tone],
        MembershipStyle.ink => [
          (AppColors.inkSoft, Colors.white),
          (AppColors.inkSoft, Colors.white),
          (AppColors.inkSoft, AppColors.gymPointYellow),
        ][tone],
      };
      return StatusPill(text, color: fg, background: bg);
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            iconTile,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                membership.name,
                style: AppTextStyles.heading2.copyWith(
                  color: textColor,
                  fontSize: 21,
                ),
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: textColor),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          formatPrice(membership.priceVnd),
          style: AppTextStyles.display.copyWith(
            color: ink ? AppColors.gymPointYellow : AppColors.ink,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            pill('${membership.durationDays} ngày', 0),
            pill('+${formatNumber(membership.pointsPerCheckin)} GP / ngày', 1),
            pill(
              '+${formatNumber(membership.pointsOnActivation)} GP kích hoạt',
              2,
            ),
            if (status != null)
              StatusPill(
                status!,
                color: AppColors.success,
                background: AppColors.mint,
              ),
          ],
        ),
        if (membership.description.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            membership.description,
            style: AppTextStyles.body.copyWith(
              color: ink ? Colors.white70 : AppColors.ink,
            ),
          ),
        ],
      ],
    );
    if (light) return AppCard(onTap: onTap, child: content);
    return HighlightCard(
      bubbleIntensity: ink ? 0.45 : 1,
      color: ink ? AppColors.ink : AppColors.primaryOrange,
      glow: ink ? AppColors.purple : AppColors.primaryOrange,
      seed: membership.name.length,
      onTap: onTap,
      child: content,
    );
  }
}

class ComingSoonCard extends StatelessWidget {
  final String title, message;
  final IconData icon;
  const ComingSoonCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.schedule_rounded,
  });
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconTile(icon),
            const SizedBox(width: 12),
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
