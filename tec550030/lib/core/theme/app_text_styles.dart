import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

// Baloo 2 for titles and numbers, Be Vietnam Pro for everything else.
class AppTextStyles {
  static const String brandFont = 'Baloo2';
  static const String textFont = 'BeVietnamPro';

  static const TextStyle display = TextStyle(
    fontFamily: brandFont,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    height: 1.1,
    color: AppColors.ink,
  );

  static const TextStyle heading1 = TextStyle(
    fontFamily: brandFont,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    height: 1.15,
    color: AppColors.ink,
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: brandFont,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.ink,
  );

  static const TextStyle title = TextStyle(
    fontFamily: textFont,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static const TextStyle body = TextStyle(
    fontFamily: textFont,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.ink,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: textFont,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: AppColors.secondaryText,
  );

  static const TextStyle overline = TextStyle(
    fontFamily: textFont,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: AppColors.secondaryText,
  );

  static const TextStyle button = TextStyle(
    fontFamily: textFont,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
}
