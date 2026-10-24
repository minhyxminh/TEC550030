import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.sand),
    );
    return ThemeData(
      fontFamily: AppTextStyles.textFont,
      primaryColor: AppColors.primaryOrange,
      scaffoldBackgroundColor: AppColors.warmBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryOrange,
        onPrimary: AppColors.ink,
        primaryContainer: AppColors.peach,
        onPrimaryContainer: AppColors.deepOrange,
        secondary: AppColors.purple,
        onSecondary: Colors.white,
        error: AppColors.error,
        surface: AppColors.warmBackground,
        onSurface: AppColors.ink,
        onSurfaceVariant: AppColors.secondaryText,
        outline: AppColors.sand,
        outlineVariant: AppColors.sand,
        surfaceTint: Colors.transparent,
      ),
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.display,
        titleLarge: AppTextStyles.heading1,
        titleMedium: AppTextStyles.heading2,
        bodyLarge: AppTextStyles.body,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.caption,
        labelLarge: AppTextStyles.button,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.warmBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 68,
        iconTheme: const IconThemeData(color: AppColors.ink),
        // Same brown lettering and amber glow as the page titles.
        titleTextStyle: AppTextStyles.heading1.copyWith(
          fontSize: 28,
          color: const Color(0xFF6B3519),
          shadows: const [
            Shadow(color: Color(0x99FF9F43), blurRadius: 12),
            Shadow(color: Color(0x73FF9F43), blurRadius: 2),
          ],
        ),
      ),
      // Back and close buttons sit in a white rounded square.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) =>
            const _SquareIcon(Icons.arrow_back_rounded),
        closeButtonIconBuilder: (_) => const _SquareIcon(Icons.close_rounded),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryOrange,
          foregroundColor: AppColors.ink,
          disabledBackgroundColor: AppColors.sand,
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: rounded,
          textStyle: AppTextStyles.button.copyWith(fontSize: 14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryOrange,
          foregroundColor: AppColors.ink,
          shape: rounded,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: Colors.white,
          minimumSize: const Size(48, 46),
          side: const BorderSide(color: AppColors.ink, width: 1.5),
          shape: rounded,
          textStyle: AppTextStyles.button.copyWith(fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.deepOrange,
          textStyle: AppTextStyles.title.copyWith(fontSize: 14),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.field,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.secondaryText),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(
            color: AppColors.primaryOrange,
            width: 1.6,
          ),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.ink : null,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primaryOrange
              : AppColors.sand,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.secondaryText,
        labelStyle: AppTextStyles.title.copyWith(fontSize: 14),
        unselectedLabelStyle: AppTextStyles.title.copyWith(fontSize: 14),
        indicator: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.peach,
        side: const BorderSide(color: AppColors.sand),
        labelStyle: AppTextStyles.caption.copyWith(color: AppColors.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: AppTextStyles.title,
        subtitleTextStyle: AppTextStyles.caption,
        iconColor: AppColors.ink,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.sand, space: 1),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyles.heading2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: AppTextStyles.body.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.ink,
        selectedItemColor: Colors.white,
        unselectedItemColor: Color(0xFFB9B5C9),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryOrange,
      ),
    );
  }
}

class _SquareIcon extends StatelessWidget {
  final IconData icon;
  const _SquareIcon(this.icon);
  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      boxShadow: AppShadows.soft,
    ),
    child: Icon(icon, color: AppColors.ink, size: 22),
  );
}
