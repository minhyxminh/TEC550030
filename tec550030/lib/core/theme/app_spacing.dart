import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double section = 28;
  static const double page = 20;

  /// Room below scrolling content for the floating navigation bar.
  static const double navClearance = 120;
}

class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 28;
}

class AppShadows {
  static List<BoxShadow> get soft => [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.05),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
  static List<BoxShadow> get lifted => [
    BoxShadow(
      color: AppColors.primaryOrange.withValues(alpha: 0.30),
      blurRadius: 26,
      offset: const Offset(0, 12),
    ),
  ];

  /// Solid "block" shadow under primary buttons.
  static List<BoxShadow> get block => const [
    BoxShadow(color: AppColors.ink, offset: Offset(0, 5)),
  ];

  /// Orange "block" under ink buttons and selected chips.
  static List<BoxShadow> get orangeBlock => const [
    BoxShadow(color: AppColors.primaryOrange, offset: Offset(0, 5)),
  ];
}
