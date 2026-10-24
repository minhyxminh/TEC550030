import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../models/machine_guide.dart';

class MachineThumbnail extends StatelessWidget {
  final MachineGuide guide;
  final double radius;
  final bool large;
  const MachineThumbnail({
    super.key,
    required this.guide,
    this.radius = AppRadius.md,
    this.large = false,
  });
  @override
  Widget build(BuildContext context) {
    final art = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: guide.colors,
        ),
      ),
      child: Stack(
        children: [
          Positioned(right: -30, top: -30, child: _ring(large ? 170 : 120)),
          Positioned(left: -20, bottom: -40, child: _ring(large ? 140 : 100)),
          Positioned(
            right: large ? 24 : 10,
            top: large ? 18 : 8,
            child: Icon(
              guide.icon,
              size: large ? 96 : 56,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Offline or while loading, the branded artwork stands in.
          if (guide.thumbnailUrl != null)
            Image.network(
              guide.thumbnailUrl!,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => art,
              frameBuilder: (_, child, frame, sync) =>
                  sync || frame != null ? child : art,
            )
          else
            art,
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.18),
                ],
              ),
            ),
          ),
          Center(
            child: Container(
              width: large ? 64 : 44,
              height: large ? 64 : 44,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange,
                shape: BoxShape.circle,
                boxShadow: AppShadows.lifted,
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: AppColors.ink,
                size: large ? 40 : 28,
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 10,
            child: _Chip(guide.level.label, light: true),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: _Chip(guide.durationLabel, icon: Icons.schedule_rounded),
          ),
        ],
      ),
    );
  }

  Widget _ring(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.18),
        width: 18,
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool light;
  const _Chip(this.text, {this.icon, this.light = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: light ? AppColors.mint : AppColors.ink,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 3),
        ],
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: light ? AppColors.success : Colors.white,
          ),
        ),
      ],
    ),
  );
}

class MuscleTags extends StatelessWidget {
  final List<String> muscles;
  final int? max;
  const MuscleTags(this.muscles, {super.key, this.max});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final muscle in max == null ? muscles : muscles.take(max!))
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.field,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            muscle,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
    ],
  );
}

/// Horizontal home card: thumbnail, title, muscles and a watch button.
class MachineGuideCard extends StatelessWidget {
  final MachineGuide guide;
  final VoidCallback onTap;
  final VoidCallback? onWatch;
  final double width;
  const MachineGuideCard({
    super.key,
    required this.guide,
    required this.onTap,
    this.onWatch,
    this.width = 228,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),

        boxShadow: AppShadows.soft,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 126,
                  width: double.infinity,
                  child: MachineThumbnail(guide: guide),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    // Large text clips here instead of overflowing the card.
                    child: ClipRect(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              guide.name,
                              style: AppTextStyles.title.copyWith(fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              guide.subtitle,
                              style: AppTextStyles.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            MuscleTags(guide.muscles, max: 2),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: FilledButton.icon(
                      onPressed: onWatch ?? onTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.peach,
                        foregroundColor: AppColors.ink,
                        minimumSize: const Size(0, 38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      icon: const Icon(Icons.play_circle_rounded, size: 18),
                      label: const Text('Xem ngay'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
