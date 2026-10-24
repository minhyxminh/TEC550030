import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';

/// Full-width action. Primary is orange on a solid ink "block" shadow;
/// [dark] is an ink button; [isSecondary] is outlined.
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isSecondary;
  final bool isLoading;
  final bool dark;
  final IconData? icon;
  final Color? accent;

  /// Icon before the label; defaults to before for outlined buttons only.
  final bool? leadingIcon;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isSecondary = false,
    this.isLoading = false,
    this.dark = false,
    this.icon,
    this.accent,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final secondaryColor = accent ?? AppColors.ink;
    final background = isSecondary
        ? AppColors.white
        : dark
        ? AppColors.ink
        : AppColors.primaryOrange;
    final foreground = isSecondary
        ? secondaryColor
        : dark
        ? AppColors.white
        : AppColors.ink;
    final lead = leadingIcon ?? isSecondary;
    final label = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null && lead) ...[
          Icon(icon, size: 20),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.button.copyWith(
              color: enabled ? foreground : AppColors.secondaryText,
            ),
          ),
        ),
        if (icon != null && !lead) ...[
          const SizedBox(width: 8),
          Icon(icon, size: 20),
        ],
      ],
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 54,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md + 2),
        boxShadow: isSecondary || !enabled
            ? null
            : dark
            ? AppShadows.orangeBlock
            : AppShadows.block,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: isSecondary
              ? AppColors.white
              : AppColors.sand,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md + 2),
            side: isSecondary
                ? BorderSide(
                    color: secondaryColor.withValues(alpha: 0.45),
                    width: 1.5,
                  )
                : BorderSide.none,
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: dark ? AppColors.white : AppColors.ink,
                ),
              )
            : label,
      ),
    );
  }
}
